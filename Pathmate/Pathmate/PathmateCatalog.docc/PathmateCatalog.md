# ``Pathmate``

Pathmate helps international students plan their move with **checklists**, a **planner**, and an interactive **widget**.

![Home](home-page.png)

## Topics

### Getting Started
- <doc:Architecture>
- <doc:DataModel>
- <doc:UXAndAccessibility>
- <doc:PlannerAndProgress>
- <doc:WidgetIntegration>

### Screens
- ``HomeView``
- ``JourneyView``
- ``ChecklistView``
- ``TaskDetailView``
- ``SetupView``
- ``AuthScreen``

### App Structure
- ``PathmateApp``
- ``AuthGate``

### Models
- ``Stage``
- ``StageID``
- ``Tint``
- ``ChecklistTask``
- ``TaskDetail``
- ``ResourceLink``
- ``UserProfile``
- ``StudyLevel``

### Persistence & Sync
- ``UserProfileEntity``
- ``TaskStateEntity``
- ``AuthService``
- ``FirestoreProfileService``
- ``FirestoreTaskStateService``
