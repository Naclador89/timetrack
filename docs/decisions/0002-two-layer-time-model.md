# 0002: Two-layer time model (attendance + projects)

- Status: accepted (2026-11-07)

## Context
The user is an employee. Working hours (for target, overtime and ArbZG) and time per project are
different questions: not every working minute belongs to a project.

## Decision
**Attendance** (work sessions with location, plus breaks) and **project entries** are separate
layers. Working time comes only from attendance. Project time is counted only where it falls inside
attendance. The rest is shown as "unassigned".

## Consequences
- Rules about working hours (overtime, ArbZG, home office, travel) never depend on project bookkeeping.
- Coupling rules keep the two layers consistent: starting a project clocks you in, clocking out stops
  the project, and a break pauses the project.
- Totals use interval unions (spec `calculations.md` §2), so duplicates from sync conflicts are harmless.
