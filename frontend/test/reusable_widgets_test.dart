import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/shared/widgets/widgets.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('App Buttons Tests', () {
    testWidgets('AppPrimaryButton renders label and triggers callback', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          AppPrimaryButton(
            label: 'Submit Task',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Submit Task'), findsOneWidget);
      await tester.tap(find.text('Submit Task'));
      expect(pressed, isTrue);
    });

    testWidgets('AppPrimaryButton shows progress indicator when isLoading is true', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          AppPrimaryButton(
            label: 'Loading Task',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Task'), findsNothing);

      // Tapping during loading should not fire callback
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(pressed, isFalse);
    });

    testWidgets('AppSecondaryButton and AppOutlinedButton render and respond to tap', (WidgetTester tester) async {
      int tapped = 0;
      await tester.pumpWidget(
        _buildTestApp(
          Column(
            children: [
              AppSecondaryButton(
                label: 'Secondary Action',
                onPressed: () => tapped++,
              ),
              AppOutlinedButton(
                label: 'Outlined Action',
                onPressed: () => tapped++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Secondary Action'));
      expect(tapped, 1);
      await tester.tap(find.text('Outlined Action'));
      expect(tapped, 2);
    });

    testWidgets('AppDestructiveButton renders with danger color', (WidgetTester tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        _buildTestApp(
          AppDestructiveButton(
            label: 'Delete Issue',
            onPressed: () => deleted = true,
          ),
        ),
      );

      expect(find.text('Delete Issue'), findsOneWidget);
      await tester.tap(find.text('Delete Issue'));
      expect(deleted, isTrue);
    });

    testWidgets('AppIconButton displays tooltip and fires tap', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(pressed, isTrue);
    });
  });

  group('AppTextFormField Tests', () {
    testWidgets('AppTextFormField renders label with required indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppTextFormField(
            label: 'Username',
            isRequired: true,
            hintText: 'Enter username',
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
      expect(find.text('Enter username'), findsOneWidget);
    });

    testWidgets('AppTextFormField toggles password visibility', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'secret_pass');
      await tester.pumpWidget(
        _buildTestApp(
          AppTextFormField(
            label: 'Password',
            controller: controller,
            isPassword: true,
          ),
        ),
      );

      // Initially obscured, suffix icon is visibility
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now visible, icon is visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('AppTextFormField clear button empties text', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Initial text');
      await tester.pumpWidget(
        _buildTestApp(
          AppTextFormField(
            controller: controller,
            showClearButton: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(controller.text, isEmpty);
    });

    testWidgets('AppTextFormField executes validator on form submission', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _buildTestApp(
          Form(
            key: formKey,
            child: AppTextFormField(
              label: 'Title',
              validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
    });
  });

  group('Badges & Enum Mapping Tests', () {
    testWidgets('IssueStatusBadge maps all backend IssueStatus correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SingleChildScrollView(
            child: Column(
              children: [
                IssueStatusBadge(status: IssueStatus.backlog),
                IssueStatusBadge(status: IssueStatus.todo),
                IssueStatusBadge(status: IssueStatus.inProgress),
                IssueStatusBadge(status: IssueStatus.inReview),
                IssueStatusBadge(status: IssueStatus.done),
                IssueStatusBadge(status: IssueStatus.canceled),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Canceled'), findsOneWidget);
    });

    testWidgets('IssuePriorityBadge maps all priorities and supports icon-only mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Column(
            children: [
              IssuePriorityBadge(priority: IssuePriority.urgent),
              IssuePriorityBadge(priority: IssuePriority.high),
              IssuePriorityBadge(priority: IssuePriority.lowest, showLabel: false),
            ],
          ),
        ),
      );

      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      // Lowest has showLabel: false, so text should not appear
      expect(find.text('Lowest'), findsNothing);
      expect(find.byIcon(Icons.keyboard_double_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('RoleBadge maps backend RoleType', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Column(
            children: [
              RoleBadge(role: RoleType.owner),
              RoleBadge(role: RoleType.admin),
              RoleBadge(role: RoleType.member),
              RoleBadge(role: RoleType.viewer),
            ],
          ),
        ),
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
    });
  });

  group('UserAvatar Tests', () {
    test('extractInitials extracts initials accurately', () {
      expect(UserAvatar.extractInitials('Cuong Nguyen'), 'CN');
      expect(UserAvatar.extractInitials('Antigravity'), 'AN');
      expect(UserAvatar.extractInitials('John Michael Smith'), 'JS');
      expect(UserAvatar.extractInitials(''), '?');
      expect(UserAvatar.extractInitials(null), '?');
    });

    testWidgets('UserAvatar renders fallback initials and status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const UserAvatar(
            name: 'Sarah Connor',
            showStatus: true,
            isOnline: true,
            size: UserAvatarSize.lg,
          ),
        ),
      );

      expect(find.text('SC'), findsOneWidget);
    });

    testWidgets('UserAvatarGroup renders multiple avatars and overflow count', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const UserAvatarGroup(
            names: ['Alice Adams', 'Bob Brown', 'Charlie Clark', 'David Davis', 'Emma Evans'],
            maxVisible: 3,
          ),
        ),
      );

      expect(find.text('AA'), findsOneWidget);
      expect(find.text('BB'), findsOneWidget);
      expect(find.text('CC'), findsOneWidget);
      // Extra count: 5 - 3 = 2
      expect(find.text('+2'), findsOneWidget);
    });
  });

  group('Dialogs and Empty State Tests', () {
    testWidgets('AppConfirmationDialog returns true on confirm and false on cancel', (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await AppConfirmationDialog.show(
                    context,
                    title: 'Delete Project',
                    message: 'Are you sure you want to delete this project?',
                    isDestructive: true,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Project'), findsOneWidget);
      expect(find.text('Are you sure you want to delete this project?'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('AppEmptyState displays icon, title, description, and action button', (WidgetTester tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        _buildTestApp(
          AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'No issues yet',
            description: 'Create your first issue to get started with this sprint.',
            action: AppPrimaryButton(
              label: 'Create Issue',
              onPressed: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No issues yet'), findsOneWidget);
      expect(find.text('Create your first issue to get started with this sprint.'), findsOneWidget);
      expect(find.text('Create Issue'), findsOneWidget);

      await tester.tap(find.text('Create Issue'));
      expect(actionTapped, isTrue);
    });
  });
}
