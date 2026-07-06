part of 'download_task.dart';

class DownloadTaskAdapter extends TypeAdapter<DownloadTask> {
  @override
  final int typeId = 2;

  @override
  DownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTask(
      id: fields[0] as String,
      sourceUrl: fields[1] as String,
      title: fields[2] as String,
      variantLabel: fields[3] as String,
      kindIndex: fields[4] as int,
      statusIndex: fields[5] as int? ?? 0,
      progress: (fields[6] as num?)?.toDouble() ?? 0,
      localPath: fields[7] as String?,
      error: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      fileSizeBytes: fields[10] as int?,
      downloadUrl: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTask obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sourceUrl)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.variantLabel)
      ..writeByte(4)
      ..write(obj.kindIndex)
      ..writeByte(5)
      ..write(obj.statusIndex)
      ..writeByte(6)
      ..write(obj.progress)
      ..writeByte(7)
      ..write(obj.localPath)
      ..writeByte(8)
      ..write(obj.error)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.fileSizeBytes)
      ..writeByte(11)
      ..write(obj.downloadUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
