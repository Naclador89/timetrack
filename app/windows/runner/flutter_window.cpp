#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

// The tray icon's mouse messages arrive as this window message.
constexpr UINT kTrayMessage = WM_APP + 1;
// Quitting is posted: the channel handler that asks for it must not be
// destroyed while it runs.
constexpr UINT kQuitMessage = WM_APP + 2;
constexpr UINT kTrayIconId = 1;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int length = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                     static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring utf16(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        utf16.data(), length);
  return utf16;
}

// Reads |key| from a channel argument map, if it holds a T.
template <typename T>
std::optional<T> Arg(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it == map.end()) {
    return std::nullopt;
  }
  if (const T* value = std::get_if<T>(&it->second)) {
    return *value;
  }
  return std::nullopt;
}

// Copies |text| into a fixed-size WCHAR buffer of the tray structure.
template <size_t N>
void CopyTo(WCHAR (&target)[N], const std::wstring& text) {
  wcsncpy_s(target, N, text.c_str(), _TRUNCATE);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_minimized)
    : project_(project), start_minimized_(start_minimized) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  taskbar_created_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "timetrack/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleWindowCall(call, std::move(result)); });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (start_minimized_) {
      ::ShowWindow(GetHandle(), SW_SHOWMINNOACTIVE);
    } else {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (tray_added_) {
    ::Shell_NotifyIconW(NIM_DELETE, &tray_);
    tray_added_ = false;
  }
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleWindowCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (method == "show") {
    ShowAndFocus();
  } else if (method == "hide") {
    ::ShowWindow(GetHandle(), SW_HIDE);
  } else if (method == "setCloseToTray") {
    const auto* on = std::get_if<bool>(call.arguments());
    close_to_tray_ = on != nullptr && *on;
  } else if (method == "setTray" && args != nullptr) {
    tray_tooltip_ = Utf16FromUtf8(Arg<std::string>(*args, "tooltip").value_or(""));
    tray_idle_ = Arg<bool>(*args, "idle").value_or(true);
    tray_items_.clear();
    if (auto items = Arg<flutter::EncodableList>(*args, "items")) {
      for (const auto& value : *items) {
        const auto* item = std::get_if<flutter::EncodableMap>(&value);
        if (item == nullptr) {
          continue;
        }
        tray_items_.push_back(TrayItem{
            Arg<std::string>(*item, "id").value_or(""),
            Utf16FromUtf8(Arg<std::string>(*item, "label").value_or("")),
            Arg<bool>(*item, "enabled").value_or(true),
            Arg<bool>(*item, "checked").value_or(false),
            Arg<bool>(*item, "separator").value_or(false),
        });
      }
    }
    UpdateTrayIcon();
  } else if (method == "notify" && args != nullptr) {
    // A balloon, which Windows 10/11 shows as a notification.
    if (!tray_added_) {
      UpdateTrayIcon();
    }
    tray_.uFlags = NIF_INFO;
    CopyTo(tray_.szInfoTitle,
           Utf16FromUtf8(Arg<std::string>(*args, "title").value_or("")));
    CopyTo(tray_.szInfo,
           Utf16FromUtf8(Arg<std::string>(*args, "body").value_or("")));
    tray_.dwInfoFlags = NIIF_INFO;
    ::Shell_NotifyIconW(NIM_MODIFY, &tray_);
  } else if (method == "quit") {
    // The real exit (tray menu, update): no hiding, and the tray icon goes
    // with the window instead of lingering until the mouse passes over it.
    close_to_tray_ = false;
    ::PostMessage(GetHandle(), kQuitMessage, 0, 0);
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

void FlutterWindow::ShowAndFocus() {
  HWND hwnd = GetHandle();
  ::ShowWindow(hwnd, ::IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  // Windows may refuse the focus to a background process; then the
  // taskbar button flashes instead.
  if (!::SetForegroundWindow(hwnd)) {
    FLASHWINFO flash = {sizeof(FLASHWINFO), hwnd,
                        FLASHW_ALL | FLASHW_TIMERNOFG, 0, 0};
    ::FlashWindowEx(&flash);
  }
}

void FlutterWindow::UpdateTrayIcon() {
  tray_.cbSize = sizeof(NOTIFYICONDATAW);
  tray_.hWnd = GetHandle();
  tray_.uID = kTrayIconId;
  tray_.uFlags = NIF_ICON | NIF_TIP | NIF_MESSAGE;
  tray_.uCallbackMessage = kTrayMessage;
  tray_.hIcon = static_cast<HICON>(::LoadImageW(
      ::GetModuleHandle(nullptr),
      MAKEINTRESOURCEW(tray_idle_ ? IDI_APP_ICON_IDLE : IDI_APP_ICON),
      IMAGE_ICON, ::GetSystemMetrics(SM_CXSMICON),
      ::GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR | LR_SHARED));
  CopyTo(tray_.szTip, tray_tooltip_);
  if (tray_added_) {
    ::Shell_NotifyIconW(NIM_MODIFY, &tray_);
  } else {
    tray_added_ = ::Shell_NotifyIconW(NIM_ADD, &tray_) != FALSE;
  }
}

void FlutterWindow::ShowTrayMenu() {
  if (tray_items_.empty()) {
    return;
  }
  HMENU menu = ::CreatePopupMenu();
  for (size_t i = 0; i < tray_items_.size(); i++) {
    const TrayItem& item = tray_items_[i];
    if (item.separator) {
      ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      continue;
    }
    UINT flags = MF_STRING | (item.enabled ? 0 : MF_GRAYED) |
                 (item.checked ? MF_CHECKED : 0);
    ::AppendMenuW(menu, flags, i + 1, item.label.c_str());
  }
  POINT cursor;
  ::GetCursorPos(&cursor);
  HWND hwnd = GetHandle();
  // Without this the menu stays open when the user clicks elsewhere.
  ::SetForegroundWindow(hwnd);
  const BOOL chosen = ::TrackPopupMenu(
      menu, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY | TPM_BOTTOMALIGN,
      cursor.x, cursor.y, 0, hwnd, nullptr);
  ::PostMessage(hwnd, WM_NULL, 0, 0);
  ::DestroyMenu(menu);
  if (chosen <= 0 || static_cast<size_t>(chosen) > tray_items_.size() ||
      !window_channel_) {
    return;
  }
  window_channel_->InvokeMethod(
      "trayAction", std::make_unique<flutter::EncodableValue>(
                        tray_items_[static_cast<size_t>(chosen) - 1].id));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Before Flutter sees it: with the tray, closing only hides the window.
  if (message == WM_CLOSE && close_to_tray_ && tray_added_) {
    ::ShowWindow(hwnd, SW_HIDE);
    return 0;
  }
  if (message == kQuitMessage) {
    ::DestroyWindow(hwnd);
    return 0;
  }
  if (message == kTrayMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
        ShowAndFocus();
        break;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        ShowTrayMenu();
        break;
    }
    return 0;
  }
  if (taskbar_created_ != 0 && message == taskbar_created_ && tray_added_) {
    tray_added_ = false;
    UpdateTrayIcon();
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
