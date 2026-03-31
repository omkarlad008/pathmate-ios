# Widget Integration

## Data flow
1. The app computes a WidgetSnapshot.
2. It’s stored via an App Group bridge (UserDefaults + file).
3. The widget reads the snapshot and renders ring + next three tasks.

## Interactions
- MarkTaskDoneIntent toggles completion and patches the snapshot.
- RescheduleTaskIntent updates `scheduledDate` and re-sorts.

## Notes
- Horizon window: **−2 days … +7 days**.
- Reload timelines with the widget’s kind identifier.
