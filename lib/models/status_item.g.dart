// GENERATED CODE (hand-written equivalent — regenerate with
// `dart run build_runner build` if you change status_item.dart)
part of 'status_item.dart';

class StatusItemAdapter extends TypeAdapter<StatusItem> {
  @override
  final int typeId = 0;

  @override
  StatusItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StatusItem(
      id: fields[0] as String,
      cachedFilePath: fields[1] as String,
      mediaTypeIndex: fields[2] as int,
      discoveredAt: fields[3] as DateTime,
      expiresAt: fields[4] as DateTime,
      isSaved: fields[5] as bool? ?? false,
      savedFilePath: fields[6] as String?,
      sourceHint: fields[7] as String?,
      isVaulted: fields[8] as bool? ?? false,
      vaultedFilePath: fields[9] as String?,
      originalFileName: fields[10] as String?,
      originalSizeBytes: fields[11] as int?,
      isMissing: fields[12] as bool? ?? false,
      sourceIndex: fields[13] as int? ?? 0,
      sourceModifiedAt: fields[14] as DateTime?,
      deletedFromWhatsApp: fields[15] as bool? ?? false,
      thumbnailPath: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StatusItem obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cachedFilePath)
      ..writeByte(2)
      ..write(obj.mediaTypeIndex)
      ..writeByte(3)
      ..write(obj.discoveredAt)
      ..writeByte(4)
      ..write(obj.expiresAt)
      ..writeByte(5)
      ..write(obj.isSaved)
      ..writeByte(6)
      ..write(obj.savedFilePath)
      ..writeByte(7)
      ..write(obj.sourceHint)
      ..writeByte(8)
      ..write(obj.isVaulted)
      ..writeByte(9)
      ..write(obj.vaultedFilePath)
      ..writeByte(10)
      ..write(obj.originalFileName)
      ..writeByte(11)
      ..write(obj.originalSizeBytes)
      ..writeByte(12)
      ..write(obj.isMissing)
      ..writeByte(13)
      ..write(obj.sourceIndex)
      ..writeByte(14)
      ..write(obj.sourceModifiedAt)
      ..writeByte(15)
      ..write(obj.deletedFromWhatsApp)
      ..writeByte(16)
      ..write(obj.thumbnailPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusItemAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
