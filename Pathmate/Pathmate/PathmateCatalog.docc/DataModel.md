# Data Model

## Core Models
- ``Stage`` / ``StageID`` / ``Tint`` — journey stages and display color tokens.
- ``ChecklistTask`` — stable `key`, title/subtitle, and ``TaskDetail``.
- ``TaskDetail`` — what/why, ordered steps, optional ``ResourceLink``(s).
- ``UserProfile`` — full name, study level, intake (month–year), city/university.

## SwiftData Entities
- ``UserProfileEntity`` — persisted user profile (mirrors ``UserProfile``).
- ``TaskStateEntity`` — per-task state: `taskKey`, stage, optional `dueDate`, `isDone`, `doneAt`, timestamps.

## Planner & Progress
- PlannerStore — scheduled tasks (overdue detection, add/remove/toggle).
- TaskProgressStore — done IDs + overall progress.

## Widget Snapshot (App Group)
- WidgetTask — minimal row (id, title, scheduledDate, isDone, stageName?).
- WidgetSnapshot — `next` (top 3), `todayScheduled`, `todayDone`, `overallTotal`, `overallDone`.

## Services & Repos
- ``TaskService`` / ``StaticTaskService`` — tasks per stage.
- ``TaskRepository`` — static definitions shared app-wide.
