from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models import (
    Issue,
    Project,
    ProjectMember,
    Sprint,
    User,
    Workspace,
    WorkspaceMember,
)
from app.models.enums import (
    IssuePriority,
    IssueStatus,
    IssueType,
    RoleType,
    SprintStatus,
)


# ---------------------------------------------------------------------------
# 1. User Integration Tests
# ---------------------------------------------------------------------------
def test_user_crud_lifecycle(db_session):
    """Test full CRUD lifecycle of User entity including soft delete."""
    # Create
    user = User(
        email="alice@example.com",
        hashed_password="secure_hashed_password",
        full_name="Alice Smith",
        avatar_url="https://example.com/alice.png",
    )
    db_session.add(user)
    db_session.commit()

    user_id = user.id
    assert user_id is not None

    # Read
    fetched = db_session.scalar(select(User).where(User.id == user_id))
    assert fetched is not None
    assert fetched.email == "alice@example.com"
    assert fetched.full_name == "Alice Smith"
    assert fetched.is_active is True
    assert fetched.deleted_at is None

    # Update
    fetched.full_name = "Alice Johnson"
    fetched.avatar_url = "https://example.com/alice_new.png"
    fetched.is_active = False
    db_session.commit()

    refreshed = db_session.scalar(select(User).where(User.id == user_id))
    assert refreshed.full_name == "Alice Johnson"
    assert refreshed.avatar_url == "https://example.com/alice_new.png"
    assert refreshed.is_active is False

    # Soft Delete
    now = datetime.now(UTC)
    refreshed.deleted_at = now
    db_session.commit()

    # Query active vs soft-deleted
    active_users = db_session.scalars(
        select(User).where(User.deleted_at.is_(None))
    ).all()
    assert user_id not in [u.id for u in active_users]

    all_users = db_session.scalars(select(User)).all()
    assert user_id in [u.id for u in all_users]


def test_user_unique_email_constraint(db_session):
    """Enforce unique constraint on User email."""
    user1 = User(email="dup@example.com", hashed_password="pwd", full_name="User 1")
    db_session.add(user1)
    db_session.commit()

    with pytest.raises(IntegrityError), db_session.begin_nested():
        user2 = User(
            email="dup@example.com", hashed_password="pwd2", full_name="User 2"
        )
        db_session.add(user2)
        db_session.flush()


# ---------------------------------------------------------------------------
# 2. Workspace Integration Tests
# ---------------------------------------------------------------------------
def test_workspace_crud_lifecycle(db_session):
    """Test full CRUD lifecycle of Workspace entity."""
    owner = User(email="ws_owner@example.com", hashed_password="pwd", full_name="Owner")
    db_session.add(owner)
    db_session.commit()

    # Create
    ws = Workspace(
        name="TechCorp Workspace",
        slug="techcorp",
        description="Engineering projects",
        owner_id=owner.id,
    )
    db_session.add(ws)
    db_session.commit()

    ws_id = ws.id
    assert ws_id is not None
    assert ws.owner.id == owner.id

    # Read by slug
    by_slug = db_session.scalar(select(Workspace).where(Workspace.slug == "techcorp"))
    assert by_slug is not None
    assert by_slug.name == "TechCorp Workspace"

    # Update
    by_slug.name = "TechCorp Global"
    by_slug.description = "Updated description"
    db_session.commit()

    refreshed = db_session.scalar(select(Workspace).where(Workspace.id == ws_id))
    assert refreshed.name == "TechCorp Global"
    assert refreshed.description == "Updated description"

    # Soft delete
    refreshed.deleted_at = datetime.now(UTC)
    db_session.commit()

    active_ws = db_session.scalars(
        select(Workspace).where(Workspace.deleted_at.is_(None))
    ).all()
    assert ws_id not in [w.id for w in active_ws]


def test_workspace_unique_slug_constraint(db_session):
    """Enforce unique slug across workspaces."""
    owner = User(
        email="owner_slug@example.com", hashed_password="pwd", full_name="Owner"
    )
    db_session.add(owner)
    db_session.commit()

    ws1 = Workspace(name="WS 1", slug="common-slug", owner_id=owner.id)
    db_session.add(ws1)
    db_session.commit()

    with pytest.raises(IntegrityError), db_session.begin_nested():
        ws2 = Workspace(name="WS 2", slug="common-slug", owner_id=owner.id)
        db_session.add(ws2)
        db_session.flush()


def test_workspace_owner_restrict_delete(db_session):
    """Cannot delete user who is owner of a workspace (ondelete=RESTRICT)."""
    owner = User(
        email="owner_restrict@example.com", hashed_password="pwd", full_name="Owner"
    )
    db_session.add(owner)
    db_session.commit()

    ws = Workspace(name="Restricted WS", slug="restricted-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    # Attempt to delete owner must fail due to foreign key restriction
    with pytest.raises(IntegrityError), db_session.begin_nested():
        db_session.delete(owner)
        db_session.flush()


# ---------------------------------------------------------------------------
# 3. Project Integration Tests
# ---------------------------------------------------------------------------
def test_project_crud_and_key_uniqueness(db_session):
    """Test Project CRUD and unique (workspace_id, key) constraint."""
    owner = User(
        email="proj_owner@example.com", hashed_password="pwd", full_name="Owner"
    )
    db_session.add(owner)
    db_session.commit()

    ws1 = Workspace(name="WS 1", slug="ws-one", owner_id=owner.id)
    ws2 = Workspace(name="WS 2", slug="ws-two", owner_id=owner.id)
    db_session.add_all([ws1, ws2])
    db_session.commit()

    # Create project in WS 1
    proj1 = Project(name="Project Alpha", key="ALPHA", workspace_id=ws1.id)
    db_session.add(proj1)
    db_session.commit()
    proj1_id = proj1.id

    # Read
    fetched = db_session.scalar(select(Project).where(Project.id == proj1_id))
    assert fetched is not None
    assert fetched.key == "ALPHA"
    assert fetched.workspace.slug == "ws-one"

    # Same key in different workspace is allowed
    proj2 = Project(name="Project Alpha Copy", key="ALPHA", workspace_id=ws2.id)
    db_session.add(proj2)
    db_session.commit()
    assert proj2.id is not None

    # Duplicate key in same workspace MUST fail
    with pytest.raises(IntegrityError), db_session.begin_nested():
        proj_dup = Project(name="Duplicate Alpha", key="ALPHA", workspace_id=ws1.id)
        db_session.add(proj_dup)
        db_session.flush()

    # Update project
    fetched.name = "Project Alpha Prime"
    db_session.commit()
    assert (
        db_session.scalar(select(Project).where(Project.id == proj1_id)).name
        == "Project Alpha Prime"
    )


def test_workspace_delete_cascades_to_projects(db_session):
    """Deleting workspace cascades to its projects."""
    owner = User(email="ws_casc@example.com", hashed_password="pwd", full_name="Owner")
    db_session.add(owner)
    db_session.commit()

    ws = Workspace(name="Cascade WS", slug="cascade-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    p1 = Project(name="P1", key="PONE", workspace_id=ws.id)
    p2 = Project(name="P2", key="PTWO", workspace_id=ws.id)
    db_session.add_all([p1, p2])
    db_session.commit()

    p1_id, p2_id = p1.id, p2.id

    db_session.delete(ws)
    db_session.commit()

    assert db_session.scalar(select(Project).where(Project.id == p1_id)) is None
    assert db_session.scalar(select(Project).where(Project.id == p2_id)) is None


# ---------------------------------------------------------------------------
# 4. Membership Integration Tests
# ---------------------------------------------------------------------------
def test_workspace_membership_lifecycle_and_uniqueness(db_session):
    """Test WorkspaceMember CRUD, roles, and uniqueness constraint."""
    owner = User(email="wm_owner@example.com", hashed_password="pwd", full_name="Owner")
    member = User(
        email="wm_member@example.com", hashed_password="pwd", full_name="Member"
    )
    db_session.add_all([owner, member])
    db_session.commit()

    ws = Workspace(name="Members WS", slug="members-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    # Add member
    wm = WorkspaceMember(workspace_id=ws.id, user_id=member.id, role=RoleType.MEMBER)
    db_session.add(wm)
    db_session.commit()
    wm_id = wm.id

    # Update role
    fetched = db_session.scalar(
        select(WorkspaceMember).where(WorkspaceMember.id == wm_id)
    )
    fetched.role = RoleType.ADMIN
    db_session.commit()

    refreshed = db_session.scalar(
        select(WorkspaceMember).where(WorkspaceMember.id == wm_id)
    )
    assert refreshed.role == RoleType.ADMIN

    # Duplicate membership must fail
    with pytest.raises(IntegrityError), db_session.begin_nested():
        dup = WorkspaceMember(
            workspace_id=ws.id, user_id=member.id, role=RoleType.VIEWER
        )
        db_session.add(dup)
        db_session.flush()


def test_project_membership_lifecycle_and_uniqueness(db_session):
    """Test ProjectMember CRUD, roles, and uniqueness constraint."""
    owner = User(email="pm_owner@example.com", hashed_password="pwd", full_name="Owner")
    member = User(
        email="pm_member@example.com", hashed_password="pwd", full_name="Member"
    )
    db_session.add_all([owner, member])
    db_session.commit()

    ws = Workspace(name="PM WS", slug="pm-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="PM Project", key="PMP", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    # Add project member
    pm = ProjectMember(project_id=proj.id, user_id=member.id, role=RoleType.MEMBER)
    db_session.add(pm)
    db_session.commit()
    pm_id = pm.id

    # Duplicate project member must fail
    with pytest.raises(IntegrityError), db_session.begin_nested():
        dup_pm = ProjectMember(
            project_id=proj.id, user_id=member.id, role=RoleType.ADMIN
        )
        db_session.add(dup_pm)
        db_session.flush()

    # Deleting user cascades to project member
    db_session.delete(member)
    db_session.commit()
    assert (
        db_session.scalar(select(ProjectMember).where(ProjectMember.id == pm_id))
        is None
    )


# ---------------------------------------------------------------------------
# 5. Sprint Integration Tests
# ---------------------------------------------------------------------------
def test_sprint_crud_lifecycle_and_transitions(db_session):
    """Test Sprint CRUD and status transitions across lifecycle."""
    owner = User(email="sp_owner@example.com", hashed_password="pwd", full_name="Owner")
    db_session.add(owner)
    db_session.commit()

    ws = Workspace(name="Sprint WS", slug="sprint-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Sprint Project", key="SPR", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    # Create sprint in PLANNED status
    sprint = Sprint(
        project_id=proj.id,
        name="Sprint 1",
        goal="Deliver MVP features",
        status=SprintStatus.PLANNED,
    )
    db_session.add(sprint)
    db_session.commit()
    sprint_id = sprint.id

    # Transition: PLANNED -> ACTIVE
    fetched = db_session.scalar(select(Sprint).where(Sprint.id == sprint_id))
    fetched.status = SprintStatus.ACTIVE
    fetched.start_date = datetime.now(UTC)
    db_session.commit()

    # Transition: ACTIVE -> COMPLETED
    fetched = db_session.scalar(select(Sprint).where(Sprint.id == sprint_id))
    fetched.status = SprintStatus.COMPLETED
    fetched.end_date = datetime.now(UTC)
    db_session.commit()

    # Transition: COMPLETED -> CLOSED
    fetched = db_session.scalar(select(Sprint).where(Sprint.id == sprint_id))
    fetched.status = SprintStatus.CLOSED
    db_session.commit()

    refreshed = db_session.scalar(select(Sprint).where(Sprint.id == sprint_id))
    assert refreshed.status == SprintStatus.CLOSED


def test_project_delete_cascades_to_sprints(db_session):
    """Deleting project cascades to its sprints."""
    owner = User(email="sp_casc@example.com", hashed_password="pwd", full_name="Owner")
    db_session.add(owner)
    db_session.commit()

    ws = Workspace(name="Sprint Casc WS", slug="sprint-casc-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Sprint Casc Proj", key="SCP", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    sprint = Sprint(
        project_id=proj.id, name="Sprint Alpha", status=SprintStatus.PLANNED
    )
    db_session.add(sprint)
    db_session.commit()
    sprint_id = sprint.id

    db_session.delete(proj)
    db_session.commit()

    assert db_session.scalar(select(Sprint).where(Sprint.id == sprint_id)) is None


# ---------------------------------------------------------------------------
# 6. Issue Integration Tests
# ---------------------------------------------------------------------------
def test_issue_crud_and_project_number_uniqueness(db_session):
    """Test Issue CRUD and unique (project_id, issue_number) constraint."""
    reporter = User(
        email="iss_rep@example.com", hashed_password="pwd", full_name="Reporter"
    )
    db_session.add(reporter)
    db_session.commit()

    ws = Workspace(name="Issue WS", slug="issue-ws", owner_id=reporter.id)
    db_session.add(ws)
    db_session.commit()

    proj1 = Project(name="Project 1", key="ONE", workspace_id=ws.id)
    proj2 = Project(name="Project 2", key="TWO", workspace_id=ws.id)
    db_session.add_all([proj1, proj2])
    db_session.commit()

    # Create issue 1 in Project 1
    issue1 = Issue(
        project_id=proj1.id,
        issue_number=1,
        title="Setup Auth",
        description="Implement JWT authentication",
        type=IssueType.STORY,
        status=IssueStatus.TODO,
        priority=IssuePriority.HIGH,
        reporter_id=reporter.id,
    )
    db_session.add(issue1)
    db_session.commit()
    issue1_id = issue1.id

    # Same issue_number in different project is allowed
    issue_p2 = Issue(
        project_id=proj2.id,
        issue_number=1,
        title="P2 Issue 1",
        type=IssueType.TASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.LOW,
        reporter_id=reporter.id,
    )
    db_session.add(issue_p2)
    db_session.commit()
    assert issue_p2.id is not None

    # Duplicate issue_number in same project MUST fail
    with pytest.raises(IntegrityError), db_session.begin_nested():
        dup = Issue(
            project_id=proj1.id,
            issue_number=1,
            title="Duplicate Number",
            type=IssueType.BUG,
            status=IssueStatus.BACKLOG,
            priority=IssuePriority.MEDIUM,
            reporter_id=reporter.id,
        )
        db_session.add(dup)
        db_session.flush()

    # Read & Update
    fetched = db_session.scalar(select(Issue).where(Issue.id == issue1_id))
    assert fetched is not None
    fetched.status = IssueStatus.IN_PROGRESS
    fetched.priority = IssuePriority.URGENT
    db_session.commit()

    refreshed = db_session.scalar(select(Issue).where(Issue.id == issue1_id))
    assert refreshed.status == IssueStatus.IN_PROGRESS
    assert refreshed.priority == IssuePriority.URGENT


def test_issue_hierarchy_parent_subtask_cascade(db_session):
    """Test parent-child issue hierarchy and cascade deletion of subtasks."""
    user = User(email="hier@example.com", hashed_password="pwd", full_name="User")
    db_session.add(user)
    db_session.commit()

    ws = Workspace(name="Hier WS", slug="hier-ws", owner_id=user.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Hier Proj", key="HIE", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    parent = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Parent Epic",
        type=IssueType.EPIC,
        status=IssueStatus.IN_PROGRESS,
        priority=IssuePriority.HIGH,
        reporter_id=user.id,
    )
    db_session.add(parent)
    db_session.commit()

    subtask1 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Subtask 1",
        type=IssueType.SUBTASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        parent_id=parent.id,
    )
    subtask2 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="Subtask 2",
        type=IssueType.SUBTASK,
        status=IssueStatus.DONE,
        priority=IssuePriority.LOW,
        reporter_id=user.id,
        parent_id=parent.id,
    )
    db_session.add_all([subtask1, subtask2])
    db_session.commit()

    sub1_id, sub2_id = subtask1.id, subtask2.id

    # Verify relationship
    refreshed_parent = db_session.scalar(select(Issue).where(Issue.id == parent.id))
    assert len(refreshed_parent.sub_issues) == 2
    assert {s.id for s in refreshed_parent.sub_issues} == {sub1_id, sub2_id}

    # Deleting parent cascades to subtasks
    db_session.delete(refreshed_parent)
    db_session.commit()

    assert db_session.scalar(select(Issue).where(Issue.id == sub1_id)) is None
    assert db_session.scalar(select(Issue).where(Issue.id == sub2_id)) is None


def test_issue_sprint_nullify_on_sprint_delete(db_session):
    """Deleting a sprint sets sprint_id on assigned issues to NULL (SET NULL)."""
    user = User(email="sp_null@example.com", hashed_password="pwd", full_name="User")
    db_session.add(user)
    db_session.commit()

    ws = Workspace(name="Sprint Null WS", slug="sn-ws", owner_id=user.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Sprint Null Proj", key="SNP", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    sprint = Sprint(project_id=proj.id, name="Sprint Beta", status=SprintStatus.ACTIVE)
    db_session.add(sprint)
    db_session.commit()
    sprint_id = sprint.id

    issue = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Assigned to Sprint",
        type=IssueType.TASK,
        status=IssueStatus.IN_PROGRESS,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        sprint_id=sprint_id,
    )
    db_session.add(issue)
    db_session.commit()
    issue_id = issue.id

    assert issue.is_backlog is False

    # Delete sprint
    db_session.delete(sprint)
    db_session.commit()

    db_session.expire_all()
    refreshed_issue = db_session.scalar(select(Issue).where(Issue.id == issue_id))
    assert refreshed_issue is not None
    assert refreshed_issue.sprint_id is None
    assert refreshed_issue.is_backlog is True


def test_issue_assignee_nullify_on_user_delete(db_session):
    """Deleting assignee user sets assignee_id to NULL (SET NULL)."""
    reporter = User(
        email="rep_null@example.com", hashed_password="pwd", full_name="Reporter"
    )
    assignee = User(
        email="asg_null@example.com", hashed_password="pwd", full_name="Assignee"
    )
    db_session.add_all([reporter, assignee])
    db_session.commit()

    ws = Workspace(name="Asg WS", slug="asg-ws", owner_id=reporter.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Asg Proj", key="ASG", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    issue = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Assigned Task",
        type=IssueType.TASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.MEDIUM,
        reporter_id=reporter.id,
        assignee_id=assignee.id,
    )
    db_session.add(issue)
    db_session.commit()
    issue_id = issue.id

    # Delete assignee user
    db_session.delete(assignee)
    db_session.commit()

    db_session.expire_all()
    refreshed_issue = db_session.scalar(select(Issue).where(Issue.id == issue_id))
    assert refreshed_issue is not None
    assert refreshed_issue.assignee_id is None


def test_issue_reporter_restrict_delete(db_session):
    """Deleting reporter user raises IntegrityError (RESTRICT)."""
    reporter = User(
        email="rep_rest@example.com", hashed_password="pwd", full_name="Reporter"
    )
    db_session.add(reporter)
    db_session.commit()

    ws = Workspace(name="Rep Rest WS", slug="rep-rest-ws", owner_id=reporter.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Rep Rest Proj", key="RRP", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    issue = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Restricted Issue",
        type=IssueType.BUG,
        status=IssueStatus.TODO,
        priority=IssuePriority.HIGH,
        reporter_id=reporter.id,
    )
    db_session.add(issue)
    db_session.commit()

    # Attempting to delete reporter must fail
    with pytest.raises(IntegrityError), db_session.begin_nested():
        db_session.delete(reporter)
        db_session.flush()


def test_issue_backlog_ranking(db_session):
    """Test backlog rank ordering and float-based reordering."""
    user = User(
        email="rank_user@example.com", hashed_password="pwd", full_name="Rank User"
    )
    db_session.add(user)
    db_session.commit()

    ws = Workspace(name="Rank WS", slug="rank-ws", owner_id=user.id)
    db_session.add(ws)
    db_session.commit()

    proj = Project(name="Rank Proj", key="RNK", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()

    # Create 3 backlog items with ranks 1000.0, 2000.0, 3000.0
    i1 = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Item 1",
        type=IssueType.STORY,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        backlog_rank=1000.0,
    )
    i2 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Item 2",
        type=IssueType.STORY,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        backlog_rank=2000.0,
    )
    i3 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="Item 3",
        type=IssueType.STORY,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        backlog_rank=3000.0,
    )
    db_session.add_all([i1, i2, i3])
    db_session.commit()

    # Fetch ordered by backlog_rank ascending
    ordered = db_session.scalars(
        select(Issue)
        .where(Issue.project_id == proj.id)
        .order_by(Issue.backlog_rank.asc())
    ).all()
    assert [i.issue_number for i in ordered] == [1, 2, 3]

    # Move Item 3 between Item 1 and Item 2 (rank = 1500.0)
    i3.backlog_rank = 1500.0
    db_session.commit()

    reordered = db_session.scalars(
        select(Issue)
        .where(Issue.project_id == proj.id)
        .order_by(Issue.backlog_rank.asc())
    ).all()
    assert [i.issue_number for i in reordered] == [1, 3, 2]


# ---------------------------------------------------------------------------
# 7. Transaction Isolation Verification
# ---------------------------------------------------------------------------
def test_transaction_isolation_clean_state(db_session):
    """Verify that every test begins with a completely isolated and clean state."""
    # Count of all users in this isolated session should be 0 (all previous test changes rolled back)
    user_count = len(db_session.scalars(select(User)).all())
    assert user_count == 0

    workspace_count = len(db_session.scalars(select(Workspace)).all())
    assert workspace_count == 0

    project_count = len(db_session.scalars(select(Project)).all())
    assert project_count == 0
