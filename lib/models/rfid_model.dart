import 'package:firebase_database/firebase_database.dart';

class RFIDModel {
 final String rfid_uid;
 final Status status;
 final String? assignedTo;
 final dynamic createdAt;

 RFIDModel({
  required this.rfid_uid,
  required this.status,
  this.assignedTo,
  required this.createdAt,
 });

  RFIDModel copyWith({
    String? rfid_uid,
    Status? status,
    String? assignedTo,
    String? createdAt,

  }) {
    return RFIDModel(
      rfid_uid: rfid_uid ?? this.rfid_uid,
      status : status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'status' : status.name,
    'assignedTo' : assignedTo,
    'createdAt' : ServerValue.timestamp,
  };

  factory RFIDModel.fromJson(Map<String, dynamic> json) => RFIDModel(
    rfid_uid: json['rfid_uid'],
    status: Status.values.firstWhere((e) => e.name == json['status']),
    assignedTo: json['assignedTo'],
    createdAt: json['createdAt'],
    );
  }

enum Status { active, inactive }
