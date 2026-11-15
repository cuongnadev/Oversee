import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';

/// Sprint domain entity mapped 100% to Oversee backend `SprintResponse`.
class SprintModel extends Equatable {
  final String id;
  final String projectId;
  final String name;
  final String? goal;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? capacity;
  final SprintStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const SprintModel({
    required this.id,
    required this.projectId,
    required this.name,
    this.goal,
    this.startDate,
    this.endDate,
    this.capacity,
    this.status = SprintStatus.planned,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isActive => status == SprintStatus.active;
  bool get isCompleted => status == SprintStatus.completed;
  bool get isClosed => status == SprintStatus.closed;
  bool get isPlanned => status == SprintStatus.planned;

  /// Returns user-friendly date range string (e.g., "Oct 12 - Oct 26, 2026").
  String get dateRangeText {
    if (startDate == null && endDate == null) return 'No dates set';
    final formatter = DateFormat('MMM d');
    final yearFormatter = DateFormat('MMM d, yyyy');

    if (startDate != null && endDate != null) {
      if (startDate!.year == endDate!.year) {
        return '${formatter.format(startDate!)} - ${yearFormatter.format(endDate!)}';
      }
      return '${yearFormatter.format(startDate!)} - ${yearFormatter.format(endDate!)}';
    } else if (startDate != null) {
      return 'Starts ${yearFormatter.format(startDate!)}';
    } else {
      return 'Ends ${yearFormatter.format(endDate!)}';
    }
  }

  /// Calculates remaining days until sprint end date.
  int? get daysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    final difference = endDate!.difference(now).inDays;
    return difference < 0 ? 0 : difference;
  }

  factory SprintModel.fromJson(Map<String, dynamic> json) {
    return SprintModel(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      goal: json['goal'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      capacity: (json['capacity'] as num?)?.toDouble(),
      status: SprintStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'goal': goal,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'capacity': capacity,
      'status': status.value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  SprintModel copyWith({
    String? id,
    String? projectId,
    String? name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
    SprintStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return SprintModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        name,
        goal,
        startDate,
        endDate,
        capacity,
        status,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
