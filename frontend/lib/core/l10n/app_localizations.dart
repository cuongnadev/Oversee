import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:frontend/core/enums/app_enums.dart';

/// Strongly-typed bilingual localization (English & Vietnamese) for Oversee.
///
/// Works inside `MaterialApp` via [delegate] and degrades safely to English
/// in isolated widget tests that omit localization delegates.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const Locale en = Locale('en');
  static const Locale vi = Locale('vi');

  static const List<Locale> supportedLocales = [en, vi];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final found = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (found != null) return found;
    final maybeLocale = Localizations.maybeLocaleOf(context);
    return AppLocalizations(maybeLocale?.languageCode == 'vi' ? vi : en);
  }

  bool get isVi => locale.languageCode == 'vi';

  String tr(String enText, String viText) => isVi ? viText : enText;

  // ── Language & Appearance Settings ──────────────────────────────────────────
  String get language => tr('Language', 'Ngôn ngữ');
  String get english => tr('English', 'Tiếng Anh');
  String get vietnamese => tr('Vietnamese', 'Tiếng Việt');
  String get languageCodeLabel => isVi ? 'VI' : 'EN';
  String get switchLanguageTooltip => tr(
        'Switch language (EN / VI)',
        'Đổi ngôn ngữ (EN / VI)',
      );

  String get appearanceAndSettings => tr('Appearance & Preferences', 'Giao diện & Tùy chỉnh');
  String get appearanceAndAccent => tr('Appearance & Accent Color', 'Giao diện & Màu chủ đạo');
  String get themeMode => tr('Theme Mode', 'Chế độ hiển thị');
  String get light => tr('Light', 'Sáng');
  String get dark => tr('Dark', 'Tối');
  String get system => tr('System', 'Hệ thống');
  String get seedColor => tr('Seed Color', 'Màu chủ đạo');
  String get seedColorDescription => tr(
        'Applies synchronously across buttons, badges, charts, and active indicators.',
        'Áp dụng đồng bộ trên nút bấm, nhãn, biểu đồ và chỉ báo đang chọn.',
      );
  String get customHexColor => tr('Custom Hex Color', 'Mã màu Hex tùy chỉnh');
  String get invalidHexColor => tr(
        'Enter a valid 6-digit hex color (e.g. #2563EB)',
        'Nhập mã màu hex 6 ký tự hợp lệ (VD: #2563EB)',
      );
  String get apply => tr('Apply', 'Áp dụng');
  String get confirm => tr('Confirm', 'Xác nhận');
  String get cancel => tr('Cancel', 'Hủy');
  String get done => tr('Done', 'Xong');
  String get close => tr('Close', 'Đóng');
  String get reset => tr('Reset', 'Đặt lại');
  String get resetToDefaultViolet => tr('Reset to Default Violet', 'Khôi phục màu tím mặc định');

  String get fontSize => tr('Font Size', 'Cỡ chữ');
  String get fontSizeDescription => tr(
        'Adjust in 10% steps and press Confirm to apply.',
        'Điều chỉnh theo từng bước 10% và nhấn Xác nhận để áp dụng.',
      );
  String get wholeAppFontSize => tr('Whole App Font Size', 'Cỡ chữ toàn ứng dụng');
  String get contentPaneFontSize => tr('Content Pane Font Size', 'Cỡ chữ vùng nội dung');
  String get decreaseFontSizeTooltip => tr('Decrease by 10%', 'Giảm 10%');
  String get increaseFontSizeTooltip => tr('Increase by 10%', 'Tăng 10%');
  String get fontSizeApplied => tr('Font size updated', 'Đã cập nhật cỡ chữ');

  // ── Topbar & Shell Navigation ───────────────────────────────────────────────
  String get navigationMenu => tr('Navigation Menu', 'Menu điều hướng');
  String get searchOrCommand => tr('Search or command...', 'Tìm kiếm hoặc lệnh...');
  String get searchOrCommandTooltip => tr('Search or command (⌘K)', 'Tìm kiếm hoặc lệnh (⌘K)');
  String get create => tr('Create', 'Tạo mới');
  String get quickCreateTooltip => tr('Quick Create', 'Tạo nhanh');
  String get seedColorAndThemeTooltip => tr('Seed Color & Theme', 'Màu chủ đạo & Giao diện');
  String get notifications => tr('Notifications', 'Thông báo');
  String get markAllRead => tr('Mark all read', 'Đánh dấu đã đọc');
  String get allCaughtUp => tr('You are all caught up!', 'Bạn đã xem hết thông báo!');
  String get keyboardShortcuts => tr('Keyboard Shortcuts', 'Phím tắt');
  String get keyboardShortcutsTooltip => tr('Keyboard Shortcuts (?)', 'Phím tắt (?)');
  String get toggleThemeTooltip => tr('Toggle Theme', 'Chuyển giao diện Sáng/Tối');
  String get userProfileTooltip => tr('User Profile', 'Tài khoản');
  String get allWorkspaces => tr('All Workspaces', 'Tất cả không gian làm việc');
  String get workspaceSettings => tr('Workspace Settings', 'Cài đặt không gian làm việc');
  String get logOut => tr('Log Out', 'Đăng xuất');
  String get logOutConfirmMessage => tr(
        'Are you sure you want to log out of Oversee?',
        'Bạn có chắc chắn muốn đăng xuất khỏi Oversee không?',
      );
  String get production => tr('production', 'production');
  String get yourProjects => tr('Your Projects', 'Dự án của bạn');
  String get newIssue => tr('New Issue', 'Tạo công việc');
  String get newEpic => tr('New Epic', 'Tạo Epic');
  String get newSprint => tr('New Sprint', 'Tạo Sprint');
  String get newDocument => tr('New Document', 'Tạo tài liệu');
  String get searchPlaceholder => tr('Jump to view, create, or run action...', 'Đi tới màn hình, tạo mới hoặc thực hiện lệnh...');

  String navGroupLabel(String groupKey) {
    switch (groupKey.toUpperCase()) {
      case 'WORKSPACE':
        return tr('WORKSPACE', 'KHÔNG GIAN LÀM VIỆC');
      case 'PLANNING':
        return tr('PLANNING', 'LẬP KẾ HOẠCH');
      case 'KNOWLEDGE':
        return tr('KNOWLEDGE', 'TRI THỨC');
      case 'AI TEAM':
        return tr('AI TEAM', 'ĐỘI NGŨ AI');
      case 'CONFIGURATION':
        return tr('CONFIGURATION', 'CẤU HÌNH');
      default:
        return groupKey;
    }
  }

  String navLabel(String keyName, [String? fallback]) {
    switch (keyName) {
      case 'inbox':
        return tr('Inbox', 'Hộp thư đến');
      case 'my_tasks':
        return tr('My Tasks', 'Việc của tôi');
      case 'overview':
        return tr('Overview', 'Tổng quan');
      case 'board':
        return tr('Board', 'Bảng Kanban');
      case 'backlog':
        return tr('Backlog', 'Backlog');
      case 'issues':
        return tr('Issues', 'Công việc');
      case 'sprints':
        return tr('Sprints', 'Sprint');
      case 'planning':
        return tr('Sprint Planning', 'Lập kế hoạch Sprint');
      case 'roadmap':
        return tr('Roadmap', 'Lộ trình');
      case 'timeline':
        return tr('Timeline', 'Dòng thời gian');
      case 'calendar':
        return tr('Calendar', 'Lịch');
      case 'initiatives':
        return tr('Initiatives & Epics', 'Sáng kiến & Epic');
      case 'documents':
        return tr('Documents', 'Tài liệu');
      case 'reports':
        return tr('Reports', 'Báo cáo');
      case 'dashboard':
        return tr('Dashboard', 'Bảng điều khiển');
      case 'ai_assistant':
        return tr('AI Assistant', 'Trợ lý AI');
      case 'auto_schedule':
        return tr('Auto Schedule', 'Tự động xếp lịch');
      case 'members':
        return tr('Members', 'Thành viên');
      case 'notifications':
        return tr('Notifications', 'Thông báo');
      case 'integrations':
        return tr('Integrations', 'Tích hợp');
      case 'settings':
        return tr('Project Settings', 'Cài đặt dự án');
      case 'api_docs':
        return tr('API docs', 'Tài liệu API');
      case 'developer':
        return tr('Developer / MCP', 'Nhà phát triển / MCP');
      default:
        return fallback ?? keyName;
    }
  }

  String tabLabel(String tabId, String fallback) {
    switch (tabId) {
      case 'overview':
        return tr('Overview', 'Tổng quan');
      case 'board':
        return tr('Kanban Board', 'Bảng Kanban');
      case 'backlog':
        return tr('Backlog', 'Backlog');
      case 'issues':
        return tr('Issues', 'Công việc');
      case 'timeline':
        return tr('Timeline', 'Dòng thời gian');
      case 'calendar':
        return tr('Calendar', 'Lịch');
      case 'sprints':
        return tr('Sprint Planning', 'Kế hoạch Sprint');
      case 'dashboard':
        return tr('Dashboard', 'Thống kê');
      case 'settings':
        return tr('Settings', 'Cài đặt');
      default:
        return fallback;
    }
  }

  String viewTitle(String rawTitle) {
    switch (rawTitle.toLowerCase()) {
      case 'overview':
        return tr('Overview', 'Tổng quan');
      case 'board':
      case 'kanban board':
        return tr('Kanban Board', 'Bảng Kanban');
      case 'backlog':
        return tr('Backlog', 'Backlog');
      case 'product backlog':
        return tr('Product Backlog', 'Product Backlog');
      case 'issues':
        return tr('Issues', 'Công việc');
      case 'sprints':
        return tr('Sprints', 'Sprint');
      case 'sprint planning':
        return tr('Sprint Planning', 'Kế hoạch Sprint');
      case 'timeline':
        return tr('Timeline', 'Dòng thời gian');
      case 'calendar':
        return tr('Calendar', 'Lịch');
      case 'dashboard':
      case 'project dashboard':
        return tr('Dashboard', 'Thống kê');
      case 'settings':
      case 'project settings':
        return tr('Settings', 'Cài đặt');
      case 'workspaces':
        return tr('Workspaces', 'Không gian làm việc');
      case 'projects':
        return tr('Projects', 'Dự án');
      case 'inbox':
        return tr('Inbox', 'Hộp thư đến');
      case 'my tasks':
        return tr('My Tasks', 'Việc của tôi');
      case 'roadmap':
        return tr('Roadmap', 'Lộ trình');
      case 'documents':
        return tr('Documents', 'Tài liệu');
      case 'reports':
        return tr('Reports', 'Báo cáo');
      case 'members':
        return tr('Members', 'Thành viên');
      default:
        return rawTitle;
    }
  }

  // ── Overview Page & 3 Work Sections ─────────────────────────────────────────
  String greetingForHour(int hour) {
    if (hour < 12) return tr('Good morning', 'Chào buổi sáng');
    if (hour < 18) return tr('Good afternoon', 'Chào buổi chiều');
    return tr('Good evening', 'Chào buổi tối');
  }

  String get workspaceOverviewEyebrow => tr('WORKSPACE OVERVIEW', 'TỔNG QUAN DỰ ÁN');
  String get overviewSubtitleFallback => tr(
        'A fresh day to build something great with your team.',
        'Một ngày mới để cùng đội ngũ tạo nên những giá trị tuyệt vời.',
      );
  String get customize => tr('Customize', 'Tùy chỉnh');
  String get customizeOverview => tr('Customize Overview', 'Tùy chỉnh Tổng quan');
  String get visibleSections => tr('Visible Sections', 'Các mục hiển thị');
  String get workFocusSectionsToggle => tr(
        'Ongoing, Upcoming & Participant Workloads',
        'Việc đang làm, Sắp tới & Khối lượng thành viên',
      );
  String get sprintBurndownAndDonut => tr(
        'Sprint Burndown & Status Donut',
        'Biểu đồ Burndown & Phân bổ trạng thái',
      );
  String get velocityAndRecentActivity => tr(
        'Velocity & Recent Activity',
        'Tốc độ Sprint & Hoạt động gần đây',
      );
  String get appSeedColor => tr('App Seed Color', 'Màu chủ đạo ứng dụng');
  String get settings => tr('Settings', 'Cài đặt');
  String get failedToLoadProject => tr('Failed to load project', 'Không thể tải dự án');
  String get retry => tr('Retry', 'Thử lại');
  String get projectNotFound => tr('Project not found', 'Không tìm thấy dự án');
  String get projectNotFoundDesc => tr(
        'The requested project could not be found or has been removed.',
        'Dự án yêu cầu không tồn tại hoặc đã bị xóa.',
      );
  String get syncedFromLiveData => tr('Synced from live project data', 'Đồng bộ từ dữ liệu dự án trực tiếp');
  String blockersSummary(int count) {
    if (count == 0) {
      return tr(
        '0 high-priority blocker issues in sprint',
        '0 công việc ưu tiên cao đang bị chặn trong sprint',
      );
    }
    return tr(
      '$count high-priority issue${count == 1 ? '' : 's'} needing attention',
      '$count công việc ưu tiên cao cần chú ý',
    );
  }

  String get sprintBurndown => tr('Sprint Burndown', 'Biểu đồ Sprint Burndown');
  String get storyPointsRemaining => tr(
        'Story points remaining over sprint duration',
        'Điểm câu chuyện còn lại theo thời gian sprint',
      );
  String get startActiveSprintHint => tr(
        'Start an active sprint to track daily burndown progress.',
        'Bắt đầu một sprint đang chạy để theo dõi tiến độ burndown hằng ngày.',
      );
  String get projectArchivedTitle => tr('This project is currently archived.', 'Dự án này hiện đang được lưu trữ.');
  String get projectArchivedDesc => tr(
        'Archived projects are read-only and hidden from active workspace project lists.',
        'Dự án lưu trữ ở chế độ chỉ đọc và ẩn khỏi danh sách dự án đang hoạt động.',
      );
  String get restoreProject => tr('Restore Project', 'Khôi phục dự án');
  String get projectRestoredSuccess => tr('Project restored successfully!', 'Đã khôi phục dự án thành công!');
  String get activeBadge => tr('ACTIVE', 'HOẠT ĐỘNG');
  String get archivedBadge => tr('ARCHIVED', 'LƯU TRỮ');
  String get teamMembers => tr('Team Members', 'Thành viên dự án');
  String get manageMembers => tr('Manage Members', 'Quản lý thành viên');
  String get noMembersFound => tr('No members found in this project.', 'Chưa có thành viên nào trong dự án này.');

  // Overview 3 Horizontal Work Sections
  String get myOngoingJobs => tr('My Ongoing Jobs', 'Công việc đang làm của tôi');
  String get myOngoingJobsSubtitle => tr('Assigned to you & active', 'Được giao cho bạn & đang xử lý');
  String get noOngoingJobs => tr('No ongoing jobs assigned to you.', 'Bạn hiện không có công việc nào đang xử lý.');

  String get upcomingJobs => tr('Upcoming Jobs', 'Công việc sắp tới');
  String get upcomingJobsSubtitle => tr('Planned sprints & scheduled dates', 'Sprint kế tiếp & lịch dự kiến');
  String get noUpcomingJobs => tr('No upcoming scheduled jobs yet.', 'Chưa có công việc sắp tới nào được lên lịch.');

  String get participantWorkloads => tr('Project Participant Workloads', 'Khối lượng công việc thành viên');
  String get participantWorkloadsSubtitle => tr('Tasks & completion by member', 'Số việc & tiến độ theo thành viên');
  String get noParticipantWorkloads => tr('No participant workload data yet.', 'Chưa có dữ liệu khối lượng công việc.');
  String get unassigned => tr('Unassigned', 'Chưa giao');
  String get openIssuesCount => tr('open', 'đang mở');
  String issuesAndPoints(int count, int points) => tr(
        '$count issue${count == 1 ? '' : 's'} · $points pts',
        '$count việc · $points điểm',
      );
  String doneOfTotal(int done, int total) => tr('$done/$total done', '$done/$total xong');
  String get startsLabel => tr('Starts', 'Bắt đầu');
  String get dueLabel => tr('Due', 'Hạn');
  String get viewAll => tr('View all', 'Xem tất cả');

  // ── Auth & Common Enums ─────────────────────────────────────────────────────
  String get signIn => tr('Sign In', 'Đăng nhập');
  String get signUp => tr('Sign Up', 'Đăng ký');
  String get createAccount => tr('Create Account', 'Tạo tài khoản');
  String get email => tr('Email', 'Email');
  String get password => tr('Password', 'Mật khẩu');
  String get fullName => tr('Full Name', 'Họ và tên');

  String statusLabel(IssueStatus status) {
    switch (status) {
      case IssueStatus.backlog:
        return tr('Backlog', 'Backlog');
      case IssueStatus.todo:
        return tr('To Do', 'Cần làm');
      case IssueStatus.inProgress:
        return tr('In Progress', 'Đang làm');
      case IssueStatus.inReview:
        return tr('In Review', 'Đang duyệt');
      case IssueStatus.done:
        return tr('Done', 'Hoàn thành');
      case IssueStatus.canceled:
        return tr('Canceled', 'Đã hủy');
    }
  }

  String priorityLabel(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.lowest:
        return tr('Lowest', 'Thấp nhất');
      case IssuePriority.low:
        return tr('Low', 'Thấp');
      case IssuePriority.medium:
        return tr('Medium', 'Trung bình');
      case IssuePriority.high:
        return tr('High', 'Cao');
      case IssuePriority.urgent:
        return tr('Urgent', 'Khẩn cấp');
    }
  }

  String issueTypeLabel(IssueType type) {
    switch (type) {
      case IssueType.epic:
        return tr('Epic', 'Epic');
      case IssueType.story:
        return tr('Story', 'Story');
      case IssueType.task:
        return tr('Task', 'Công việc');
      case IssueType.bug:
        return tr('Bug', 'Lỗi');
      case IssueType.subtask:
        return tr('Subtask', 'Việc phụ');
    }
  }

  String roleLabel(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return tr('Owner', 'Chủ sở hữu');
      case RoleType.admin:
        return tr('Admin', 'Quản trị');
      case RoleType.member:
        return tr('Member', 'Thành viên');
      case RoleType.viewer:
        return tr('Viewer', 'Người xem');
    }
  }

  String sprintStatusLabel(SprintStatus status) {
    switch (status) {
      case SprintStatus.planned:
        return tr('Planned', 'Đã lên kế hoạch');
      case SprintStatus.active:
        return tr('Active', 'Đang chạy');
      case SprintStatus.completed:
        return tr('Completed', 'Đã hoàn thành');
      case SprintStatus.closed:
        return tr('Closed', 'Đã đóng');
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en' || locale.languageCode == 'vi';

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocalizationsContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
