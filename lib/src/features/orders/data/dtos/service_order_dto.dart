import '../../domain/entities/branch.dart';
import '../../domain/entities/order_note.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/service_order.dart';
import '../../domain/entities/work_item.dart';

/// Přenosový model zakázky.
///
/// Odděluje tvar dat (dnes mock JSON, zítra REST payload) od doménové entity.
/// Až se změní API, mění se jen tenhle soubor - `ServiceOrder` ani UI ne.
class ServiceOrderDto {
  const ServiceOrderDto({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.customerName,
    required this.status,
    required this.branch,
    required this.receivedAt,
    required this.dueAt,
    required this.vin,
    required this.mechanicName,
    required this.serviceAdvisorName,
    required this.bay,
    required this.notes,
    required this.workItems,
  });

  final String id;
  final String licensePlate;
  final String model;
  final String customerName;
  final String status;
  final String branch;
  final String receivedAt;
  final String dueAt;
  final String vin;
  final String? mechanicName;
  final String? serviceAdvisorName;
  final String? bay;
  final List<OrderNoteDto> notes;
  final List<WorkItemDto> workItems;

  factory ServiceOrderDto.fromJson(Map<String, dynamic> json) {
    return ServiceOrderDto(
      id: json['id'] as String,
      licensePlate: json['licensePlate'] as String,
      model: json['model'] as String,
      customerName: json['customerName'] as String,
      status: json['status'] as String,
      branch: json['branch'] as String,
      receivedAt: json['receivedAt'] as String,
      dueAt: json['dueAt'] as String,
      vin: json['vin'] as String,
      mechanicName: json['mechanicName'] as String?,
      serviceAdvisorName: json['serviceAdvisorName'] as String?,
      bay: json['bay'] as String?,
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .map((item) => OrderNoteDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      workItems: (json['workItems'] as List<dynamic>? ?? const [])
          .map((item) => WorkItemDto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'licensePlate': licensePlate,
    'model': model,
    'customerName': customerName,
    'status': status,
    'branch': branch,
    'receivedAt': receivedAt,
    'dueAt': dueAt,
    'vin': vin,
    'mechanicName': mechanicName,
    'serviceAdvisorName': serviceAdvisorName,
    'bay': bay,
    'notes': notes.map((note) => note.toJson()).toList(),
    'workItems': workItems.map((item) => item.toJson()).toList(),
  };

  ServiceOrder toDomain() => ServiceOrder(
    id: id,
    licensePlate: licensePlate,
    model: model,
    customerName: customerName,
    status: OrderStatus.fromApiValue(status),
    branch: Branch.fromApiValue(branch),
    receivedAt: DateTime.parse(receivedAt),
    dueAt: DateTime.parse(dueAt),
    vin: vin,
    mechanicName: mechanicName,
    serviceAdvisorName: serviceAdvisorName,
    bay: bay,
    notes: notes.map((note) => note.toDomain()).toList(),
    workItems: workItems.map((item) => item.toDomain()).toList(),
  );

  ServiceOrderDto copyWith({
    String? status,
    List<OrderNoteDto>? notes,
    List<WorkItemDto>? workItems,
  }) {
    return ServiceOrderDto(
      id: id,
      licensePlate: licensePlate,
      model: model,
      customerName: customerName,
      status: status ?? this.status,
      branch: branch,
      receivedAt: receivedAt,
      dueAt: dueAt,
      vin: vin,
      mechanicName: mechanicName,
      serviceAdvisorName: serviceAdvisorName,
      bay: bay,
      notes: notes ?? this.notes,
      workItems: workItems ?? this.workItems,
    );
  }
}

class OrderNoteDto {
  const OrderNoteDto({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String author;
  final String createdAt;

  factory OrderNoteDto.fromJson(Map<String, dynamic> json) => OrderNoteDto(
    id: json['id'] as String,
    text: json['text'] as String,
    author: json['author'] as String,
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'author': author,
    'createdAt': createdAt,
  };

  OrderNote toDomain() => OrderNote(
    id: id,
    text: text,
    author: author,
    createdAt: DateTime.parse(createdAt),
  );
}

class WorkItemDto {
  const WorkItemDto({
    required this.id,
    required this.title,
    required this.isDone,
    required this.estimatedHours,
  });

  final String id;
  final String title;
  final bool isDone;
  final double? estimatedHours;

  factory WorkItemDto.fromJson(Map<String, dynamic> json) => WorkItemDto(
    id: json['id'] as String,
    title: json['title'] as String,
    isDone: json['isDone'] as bool? ?? false,
    estimatedHours: (json['estimatedHours'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'estimatedHours': estimatedHours,
  };

  WorkItem toDomain() => WorkItem(
    id: id,
    title: title,
    isDone: isDone,
    estimatedHours: estimatedHours,
  );

  WorkItemDto copyWith({bool? isDone}) => WorkItemDto(
    id: id,
    title: title,
    isDone: isDone ?? this.isDone,
    estimatedHours: estimatedHours,
  );
}
