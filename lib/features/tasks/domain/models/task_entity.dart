import 'package:flutter/material.dart';

enum TrackingType {
  binary,
  counter;

  static TrackingType fromString(String val) {
    return val == 'counter' ? TrackingType.counter : TrackingType.binary;
  }

  String get displayName {
    switch (this) {
      case TrackingType.binary:
        return 'Ya / Tidak (Selesai)';
      case TrackingType.counter:
        return 'Counter (Target Angka)';
    }
  }
}

class TaskEntity {
  final String id;
  final String title;
  final TrackingType type;
  final int? dailyTarget;
  final String? unit;
  final Color color;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const TaskEntity({
    required this.id,
    required this.title,
    required this.type,
    this.dailyTarget,
    this.unit,
    required this.color,
    this.sortOrder = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  TaskEntity copyWith({
    String? id,
    String? title,
    TrackingType? type,
    int? dailyTarget,
    String? unit,
    Color? color,
    int? sortOrder,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

