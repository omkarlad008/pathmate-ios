
# Pathmate

**Pathmate** is a SwiftUI-based iOS app designed to help international students settle into life in Australia through structured guidance, actionable checklists, task planning, and progress tracking.

It turns a complex transition into a simple, stage-based mobile experience covering pre-departure preparation, arrival setup, university onboarding, work compliance, and everyday student life.

---

## Overview

Moving to a new country as an international student can be overwhelming. There are many important but scattered tasks to manage, such as preparing documents, understanding university processes, completing essential errands, and keeping up with deadlines.

Pathmate was built to make this journey more manageable through a clean and practical iOS experience. The app helps users understand what to do next, stay organised, and track their progress in a way that feels simple, motivating, and useful.

This project showcases my ability to build a real-world mobile product using **SwiftUI**, **SwiftData**, modular architecture, API integration, and thoughtful UX design.

---

## Why I Built It

International students often face a common set of challenges during relocation:

- too many tasks at once
- uncertainty about what to do first
- missed setup steps after arrival
- difficulty staying organised in a new environment

I built Pathmate to solve this by breaking the journey into clear stages and actionable tasks, supported by planning tools and visible progress tracking.

---

## Features

### Stage-Based Journey Tracking

The student journey is organised into five major phases:

- Pre-departure
- Arrival
- University
- Work & Compliance
- Life & Balance

### Checklist Management

- View tasks for each stage
- Mark tasks as done or undone
- Keep track of progress across the full journey

### Planner Support

- Add tasks to a personal planner
- Manage scheduled and completed items
- Organise what needs attention next

### Next 3 Recommendations

- Highlights the next important unscheduled tasks
- Helps users focus on the most relevant upcoming actions

### Progress Tracking

- Shows overall and stage-level completion
- Uses visual indicators to make progress easy to understand

### University Search Integration

- Fetches Australian university data using the **OpenAlex API**
- Supports onboarding and setup-related decisions

### Widget Support

- Surfaces useful progress and task information outside the app
- Improves convenience and quick access

### Local Persistence

- Stores user and task state using **SwiftData**

---

## Screens

The app includes the following main screens:

- Welcome / onboarding
- Setup flow
- Dashboard / home
- Journey overview
- Checklist screen
- Task detail screen
- Planner view
- Profile / settings
- Widget extension

---

## User Flow

A typical user journey through the app looks like this:

1. Open the app and complete setup
2. Land on the dashboard
3. Explore the different journey stages
4. Open a checklist for a stage
5. Mark tasks as complete or add them to the planner
6. Track overall progress from the home screen
7. Use university search where relevant
8. View helpful progress and task information through the widget

---

## Tech Stack

- **Swift**
- **SwiftUI**
- **SwiftData**
- **MVVM-style architecture**
- **OpenAlex API**
- **Xcode**
- **iOS Simulator**

---

## Architecture

Pathmate follows a clean and modular structure to keep the codebase readable, maintainable, and easy to extend.

### Core Layers

#### Models

Represent stages, tasks, task details, and related app data.

#### Views

SwiftUI screens for onboarding, dashboard, journey flow, checklists, planner, and task details.

#### ViewModels

Manage presentation logic and screen state.

#### Services

Handle external data fetching, such as university data from OpenAlex.

#### Data / Repository Layer

Manage static task content, planner logic, and progress state.

### Key Implementation Ideas

- reusable SwiftUI components
- clear separation of UI and business logic
- local persistence with SwiftData
- API-backed search integration
- widget-based extension of the core experience

---

## What This Project Demonstrates

This project highlights my ability to:

- build a complete multi-screen iOS application with SwiftUI
- design around a real-world user problem
- structure code using modular, maintainable architecture
- work with local persistence using SwiftData
- integrate an external API into a mobile app
- create a polished and user-friendly experience
- extend app functionality with a widget

---

## Project Structure

```bash
Pathmate/
├── Models/
├── Data/
├── Services/
├── ViewModels/
├── Views/
├── Shared/
├── WidgetExtension/
└── Pathmate.xcodeproj
```

---

## Screenshots

### Example

```md
## Screenshots

### Home Screen
![Home Screen](assets/home.png)

### Journey Screen
![Journey Screen](assets/journey.png)

### Checklist Screen
![Checklist Screen](assets/checklist.png)

### Planner Screen
![Planner Screen](assets/planner.png)

### Widget
![Widget](assets/widget.png)
```

---

## How to Run

### Requirements

- macOS
- Xcode 15 or later
- iOS Simulator or a physical iPhone with a supported iOS version

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/omkarlad008/pathmate-ios.git
   ```

2. Open the project in Xcode:
   - Open the `.xcodeproj` file

3. Configure signing if required:
   - Select the project in Xcode
   - Open the app target
   - Go to **Signing & Capabilities**
   - Choose your Apple Developer team if needed

4. Select a simulator:
   - Example: **iPhone 15**

5. Build and run:
   - Press `Cmd + R`

---

## Future Improvements

If this project were extended further, possible next steps would include:

- push notifications for due tasks
- richer planner interactions
- deeper personalisation based on study level or city
- optional backend or cloud sync
- analytics around progress and completion patterns

---

## About This Project

Pathmate was created as part of an iOS software engineering project and reflects my interest in building practical, user-focused mobile products with clean architecture and thoughtful UX.

---

## Contact

**Omkar Lad**  
Frontend Developer | Full Stack Developer | Software Engineer

- **LinkedIn:** https://www.linkedin.com/in/omkarlad008/
- **Email:** omkar.lad.08@gmail.com
