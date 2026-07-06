part of 'captured_message.dart';

class CapturedMessageAdapter extends TypeAdapter<CapturedMessage> {
  @override
  final int typeId = 1;

  @override
  CapturedMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CapturedMessage(
      id: fields[0] as String,
      senderName: fields[1] as String,
      content: fields[2] as String,
      capturedAt: fields[3] as DateTime,
      sourceIndex: fields[4] as int? ?? 0,
      isSaved: fields[5] as bool? ?? false,
      wasRemoved: fields[6] as bool? ?? false,
      isDeletedNotice: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, CapturedMessage obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderName)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.capturedAt)
      ..writeByte(4)
      ..write(obj.sourceIndex)
      ..writeByte(5)
      ..write(obj.isSaved)
      ..writeByte(6)
      ..write(obj.wasRemoved)
      ..writeByte(7)
      ..write(obj.isDeletedNotice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturedMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
