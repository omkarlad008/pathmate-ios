# Planner & Progress

## Progress
- Overall = done IDs in TaskProgressStore vs total in TaskRepository.
- Widget ring = tasks due in **−2d … +7d** (denominator) vs done in that window (numerator).

## Planner rules
- Past dates allowed; show **Overdue**.
- On ``TaskDetailView``: when **done**, hide planner CTAs; when **undone**, re-enable.

## Related
- TaskProgressStore • PlannerStore • ``TaskStateEntity``
