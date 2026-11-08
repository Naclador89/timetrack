#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that hosts the Flutter view, plus TimeTrack's tray icon
// (docs/specs/work-pc.md, tray).
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // With |start_minimized| (TimeTrack started at sign-in, `--autostart`) the
  // window first appears minimized and without focus; Dart brings it to the
  // front through the `timetrack/window` channel when it has a question.
  FlutterWindow(const flutter::DartProject& project, bool start_minimized);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // One entry of the tray menu, as sent by Dart.
  struct TrayItem {
    std::string id;
    std::wstring label;
    bool enabled = true;
    bool checked = false;
    bool separator = false;
  };

  // Handles a call on `timetrack/window`.
  void HandleWindowCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Restores the window and brings it to the front (or flashes it).
  void ShowAndFocus();

  // Adds the tray icon, or updates it if it is there already.
  void UpdateTrayIcon();

  // Shows the tray menu at the cursor and reports the chosen item to Dart.
  void ShowTrayMenu();

  // The project to run.
  flutter::DartProject project_;

  // Whether to show the window minimized at first.
  bool start_minimized_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // `timetrack/window`: show/hide, the tray icon and its menu, notifications.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  // The tray icon; `tray_added_` once Dart sent its first state.
  NOTIFYICONDATAW tray_ = {};
  bool tray_added_ = false;
  bool tray_idle_ = true;
  std::wstring tray_tooltip_;
  std::vector<TrayItem> tray_items_;

  // The close button hides the window to the tray instead of quitting.
  bool close_to_tray_ = false;

  // Sent by Explorer after it restarts: the tray icon must be added again.
  UINT taskbar_created_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
