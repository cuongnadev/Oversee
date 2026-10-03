**VIETNAM - KOREA UNIVERSITY OF INFORMATION AND COMMUNICATION TECHNOLOGY · DEPARTMENT OF SOFTWARE ENGINEERING**

# Software Project Charter

**Course:** Software Project Management (SPM) | **Academic Supervisor:** Dr. Nguyen Thanh Tuan
**Submission Deadline:** End of Week 2 (Milestone M1) | **Target Length:** 3 – 5 Pages

---

## 1. PROJECT GENERAL INFORMATION

| Item | Project Details |
|---|---|
| **Project Name** | **Oversee - Nền tảng quản lý và theo dõi dự án phần mềm** |
| **Project Key / Acronym** | **OVERSEE** |
| **Course Cohort** | Software Project Management (5) |
| **Team Identifier** | **Team 04 - Oversee** |
| **Creation Date** | 19 / 09 / 2026 |
| **Document Version** | Version 1.0 (Draft) |
| **Primary GitHub Repository** | <https://github.com/cuongnadev/Oversee> |
| **GitHub Project Board URL** | <https://github.com/users/cuongnadev/projects/4> |

---

## 2. PROJECT SOURCING & REAL-WORLD CONTEXT

*Check `[x]` one of the three approved sourcing pathways according to the course syllabus:*

- [x] **Pathway 1: Capstone Project from Concurrent Engineering Course.**
- [ ] **Pathway 2: Real External Client / Freelance Project / Industry Partner**
- [ ] **Pathway 3: Real Campus / Department / Student Organization Need at VKU**

**Context:** Oversee is developed as a software engineering project for applying software project management practices to a realistic software product. The project focuses not only on implementing features but also on requirements management, work breakdown, issue tracking, GitHub-based governance, quality control, risk management, milestone management, and evidence-based project execution.

---

## 3. EXECUTIVE SUMMARY & BUSINESS CASE

### Operational Background

Software development projects require continuous coordination between requirements, tasks, milestones, team members, issues, pull requests, reviews, and project progress. In small student and software engineering teams, project information is often distributed across multiple documents, chat messages, GitHub issues, spreadsheets, and informal communication. This makes it difficult to maintain a consistent view of project status and responsibilities.

Oversee is designed as a centralized platform for managing and monitoring software projects. The system provides a structured workspace where project information, tasks, progress, team activities, and project status can be managed in one place.

### Core Problem Statement

The main problems are fragmented project information, limited visibility into project progress, difficulty tracking responsibilities and work status, and inefficient coordination between project members. Without a centralized project-management workflow, tasks can be missed, duplicated, delayed, or lack clear ownership. Project managers also have limited visibility into whether planned work is progressing according to milestones.

### Proposed Software Solution

Oversee provides a centralized software project management platform that allows teams to organize projects, manage work items, assign responsibilities, monitor progress, and maintain project visibility.

The proposed solution will provide:

- Project and workspace management.
- Task / issue creation, assignment, prioritization, and status tracking.
- Kanban-style project workflow and progress monitoring.
- Team/member management and responsibility tracking.
- Milestone and project-progress monitoring.
- Project activity and status visibility through dashboards.
- GitHub-centered engineering workflow and traceability.
- Authentication and role-based access where required by the system design.

The expected benefit is a more structured and transparent project workflow, allowing team members to understand what needs to be done, who owns each work item, and how the project is progressing toward its milestones.

---

## 4. SMART PROJECT OBJECTIVES

1. **Core Functional Objective:** Deliver the committed Oversee project-management features, including project/workspace management, task tracking, assignment, status workflow, and project-progress monitoring, with the core prototype operational by the Week 8 midterm milestone.
2. **Operational & User Validation:** Conduct functional and usability validation with project team members and pilot users before the final acceptance milestone, and record identified issues and feedback in GitHub Issues.
3. **Engineering Rigor & Quality Gate:** Enforce a GitHub-based development workflow in which committed work is traceable to GitHub Issues, changes are reviewed through Pull Requests, and automated CI checks pass before changes are merged into the protected integration/main branch.
4. **Project Governance & Traceability:** Maintain an active GitHub Project board, milestones, issue history, pull requests, and commit history throughout the project so that committed deliverables can be traced from requirements through implementation and verification.
5. **Final Delivery & Acceptance:** Complete the committed in-scope features, documentation, testing evidence, and deployment/demo package and obtain formal stakeholder/instructor acceptance by the final project milestone.

---

## 5. PROJECT SCOPE & BOUNDARIES

### 5.1. In-Scope (Committed Deliverables & Features)

**Core Module 1: Project & Workspace Management**
Create and manage software projects/workspaces, maintain project information, and provide the basic structure in which team members can organize project work.

**Core Module 2: Task / Issue & Workflow Management**
Create, edit, assign, prioritize, and track work items through a defined workflow such as Backlog → Ready → In Progress → In Review → Done. Work items should provide sufficient information for ownership, status tracking, and acceptance verification.

**Core Module 3: Project Monitoring & Collaboration**
Provide project-progress visibility, milestone tracking, team/member responsibility information, and relevant project activity so that project members and project managers can monitor the current state of the project.

**Engineering Deliverables:**
Clean GitHub repository with verifiable commit trail, active GitHub Project board, GitHub Issues, Pull Requests, automated GitHub Actions CI/CD workflows, system architecture documentation, testing evidence, deployment/demo documentation, and project-management evidence required by the SPM course.

### 5.2. Explicitly Out-of-Scope (Boundaries to Prevent Scope Creep)

- Full enterprise-scale project portfolio management across many organizations.
- Advanced enterprise resource planning, accounting, payroll, or financial management.
- Native iOS and Android applications as separate App Store / Play Store products unless explicitly approved as a later scope change.
- Complex third-party enterprise integrations that are not required for the core project-management workflow.
- Multi-region high-availability infrastructure and enterprise-scale disaster-recovery architecture.
- Features that are not directly related to the committed software project-management objectives and are introduced after the scope baseline without a formal change request.

---

## 6. STAKEHOLDER REGISTER & ENGAGEMENT MATRIX

| Stakeholder / Entity | Role in Project | Power | Interest | Engagement Strategy |
|---|---|---|---|---|
| Project Sponsor / Client / Project Owner | Requirements owner & acceptance stakeholder | High | High | **Manage Closely:** milestone demonstrations, requirement reviews, feedback collection, and formal acceptance. |
| Course Instructor / Supervisor | Academic evaluator, project-management supervisor, and milestone auditor | High | High | **Manage Closely:** submit milestone deliverables, obtain feedback, and ensure compliance with course requirements. |
| Project Engineering Team | System design, implementation, testing, documentation, and project governance | High | High | **Collaborate Daily:** GitHub Issues, Pull Requests, peer review, weekly synchronization, and project-board updates. |
| System / Network Admins | Infrastructure and security-policy stakeholders where deployment requires institutional resources | High | Low | **Keep Satisfied:** comply with infrastructure, deployment, and security requirements. |
| End Users (Students / Staff) / Pilot Testers | Users who validate usability and functional behavior | Low | High | **Keep Informed:** usability feedback, functional testing, surveys, and pilot-release updates. |
| Peer Project Teams / Academic Community | External observers and potential sources of technical/project-management feedback | Low | Low | **Monitor:** selectively collect relevant feedback and lessons learned. |

### 6.2. Power-Interest Grid

|  | **High Interest** | **Low Interest** |
|---|---|---|
| **High Power** | **MANAGE CLOSELY**<br>• Course Instructor / Supervisor | **KEEP SATISFIED**<br>• System / Infrastructure Admin (nếu có) |
| **Low Power** | **KEEP INFORMED**<br>• End Users / Pilot Testers | **MONITOR**<br>• Peer Project Teams<br>• External Academic Community |

---

## 7. PROJECT MANAGEMENT STACK & GITHUB ECOSYSTEM

The project uses the unified GitHub ecosystem for source-code management and project governance. External project-management tools such as Jira, Trello, and Asana are not required for the project-management workflow.

| Project Domain | GitHub Tool / Feature | Governance Standard |
|---|---|---|
| Source Code Repository | GitHub Repository | Protected main/integration branch; meaningful commit history; Conventional Commits such as `feat:`, `fix:`, `docs:`, and `refactor:`… |
| Project Tracking Board | GitHub Projects | Kanban workflow: Backlog → Ready → In Progress → In Review → Done. |
| Task Management | GitHub Issues | One issue per WBS deliverable. Each issue specifies acceptance criteria, assignee, and milestone. |
| Code Review & Quality | GitHub Pull Requests | All changes merged via PR; requires at least 1 peer approval and passing automated checks. |
| Milestone Tracking | GitHub Milestones | Milestones configured to match course checkpoints (M1: Charter, M2: WBS, M5: Midterm, M8: Release). |
| CI/CD Automation | GitHub Actions | Automated workflows on every PR verifying linting, code formatting, unit tests, and build stability. |

---

## 8. HIGH-LEVEL MILESTONES & SCHEDULE

| Milestone | Target Week | Major Deliverables | Responsible Role |
|---|---|---|---|
| M1 | Week 2 | Approved Project Charter & Initialized GitHub Project Board | Project Lead & Team |
| M2 | Weeks 3–4 | Work Breakdown Structure (WBS) & Requirements Traceability Matrix (RTM) | Technical Lead / PM |
| M3 | Week 5 | Iteration 1 Launch (Prioritized Backlog, Work Packages Assigned, Estimates Locked) | Entire Team |
| M4 | Weeks 6–7 | Risk Register Formalization #1 & Iteration 1 Retrospective Report | Project Lead & QA / Documentation Lead |
| M5 | Weeks 8–9 | Midterm Milestone: Working Product Prototype Demo & Iteration 2 Planning | Entire Team |
| M6 | Weeks 9–10 | Documented Evidence of AI Engineering Tool Adoption (Copilot / Cursor / Prompts) | Entire Team |
| M7 | Weeks 11–12 | Risk Register Formalization #2 & Scope Change Control Log | Project Lead / PM + BA / QA Lead |
| M8 | Week 13 | Final Client / Stakeholder Acceptance Sign-Off & Project Retrospective | Entire Team |
| M9 | Week 14 | Complete Evidence Package Submission (Audit Checklist Verification) | Entire Team |
| M10 | Week 15 | Final Oral Defense and Live System Demonstration before Committee | Entire Team |

---

## 9. DEVELOPMENT METHODOLOGY & CADENCE

- [ ] Iterative & Incremental Development
- [ ] Agile Flow / Kanban
- [ ] Hybrid (Milestone-Gated Iterative)
- [ ] Structured Sequential / Waterfall

### Methodology Justification

**Requirement Volatility:** The project has a defined initial scope, but details may be refined after prototype implementation and stakeholder feedback. An iterative approach allows the team to improve requirements and implementation without losing the overall milestone structure.

**Stakeholder Cadence:** The project follows the academic milestone schedule and uses regular internal reviews, GitHub Project updates, Pull Requests, and prototype demonstrations to validate progress. Feedback is incorporated into subsequent iterations through GitHub Issues and controlled scope changes.

**Why Hybrid:** The course requires fixed academic checkpoints (M1–M10), while software development benefits from iterative implementation and continuous feedback. The hybrid approach combines predictable milestone governance with incremental product development.

---

## 10. TEAM ORGANIZATION & GOVERNANCE ROLES

| # | Member Name | Student ID | GitHub Handle | Project Role | Primary Responsibilities |
|---|---|---|---|---|---|
| 1 | Nguyễn Anh Cường | 23IT.EB015 | @user1 | Project Lead / PM & Technical Lead | Architecture, technical decisions, backend/full-stack, code review, GitHub governance, milestone. |
| 2 | Trần Thành Vinh | 23IT.EB119 | @user2 | Full-stack Engineer | Frontend + backend, database, API, core feature implementation, integration. |
| 3 | Trần Kim Quyên | 23IT.EB083 | @user3 | Business Analyst / QA & Documentation Lead | Requirements, user stories, acceptance criteria, test cases, QA, bug tracking, documentation, project evidence. |

---

## 11. CONSTRAINTS, ASSUMPTIONS & INITIAL RISKS

### Constraints

- Hard academic/project delivery deadlines defined by the M1–M10 milestone schedule.
- Limited student-team development time and availability.
- Infrastructure and service usage should prioritize free-tier or low-cost resources unless otherwise approved.
- The project must maintain traceability and evidence through the GitHub ecosystem.

### Assumptions

- Team members are available throughout the academic project schedule.
- Stakeholders/instructor provide milestone feedback within the expected academic review cycle.
- Required development and deployment services remain available during the project.
- Team members have access to the required GitHub repositories, project boards, and development environments.

### Initial Risks

| Initial Risk | Probability | Impact | Proactive Response & Mitigation Plan |
|---|---|---|---|
| 1. Unbalanced workload or unexpected skill gaps | Medium | High | Decompose work into small GitHub Issues, assign clear ownership, review workload regularly, and use pair programming/knowledge sharing when needed. |
| 2. Scope creep from uncontrolled feature additions | High | High | Enforce Section 5.2 out-of-scope boundaries; require documented change requests and impact analysis before accepting scope changes. |
| 3. Delay in stakeholder/instructor validation | Medium | Medium | Schedule reviews in advance, prepare milestone demos early, document feedback, and maintain a buffer before academic deadlines. |
| 4. Technical integration or deployment problems | Medium | High | Validate the deployment architecture early, maintain reproducible setup instructions, use CI checks, and test critical integrations before final milestones. |
| 5. Insufficient testing or evidence for final evaluation | Medium | High | Define acceptance criteria for each work item, maintain test evidence throughout development, and conduct an Evidence Package audit before M9. |

---

## 12. SUCCESS CRITERIA & DEFINITION OF DONE (DoD)

### 12.1. Project Success Criteria

1. 100% of committed in-scope core features are implemented, tested, and operational in the final release/demo, with no unresolved critical defects.
2. Formal stakeholder/instructor acceptance is obtained for the committed project deliverables by the final acceptance milestone.
3. A complete Evidence Package is submitted containing authentic GitHub commit history, active project-board history, issues, pull requests, milestone records, and automated CI evidence.
4. The final system demonstrates the core Oversee project-management workflow end-to-end.

### 12.2. Engineering Definition of Done (DoD) for Every Work Item

- [ ] Source code is implemented, formatted, and tested locally.
- [ ] GitHub Pull Request opened referencing the target issue (e.g., `Resolves #24`).
- [ ] At least one peer review approval formally recorded on the GitHub Pull Request.
- [ ] Automated GitHub Actions CI workflow (linting, automated test suite) passes with green status.
- [ ] Security verified: no credentials, tokens, or API secrets committed to repository.
- [ ] Changes merged into integration branch (`main` / `staging`) and deployed to preview environment.
- [ ] Acceptance criteria verified by QA engineer; GitHub Issue closed and moved to `Done` on GitHub Project board.

---

## 13. FORMAL APPROVALS & SIGN-OFF

*By signing below, the signatories endorse this Project Charter, authorizing the project team to proceed with Work Breakdown Structure (WBS) decomposition and project execution.*

| Project Lead / Team Representative | Project Sponsor / Client Stakeholder | Academic Supervisor / Instructor |
|---|---|---|
| *(Signature & Full Name)*<br><br><br>**Nguyen Anh Cuong**<br>Date ........../........./ 2026 | *(Signature & Full Name)*<br><br><br>**[Client / Sponsor Full Name]**<br>Date ........../........./ 2026 | *(Signature & Full Name)*<br><br><br>**Dr. Nguyen Thanh Tuan**<br>Date ........../........./ 2026 |
