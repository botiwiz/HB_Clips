import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/clipboard_copy_service.dart';
import 'package:super_clipboard/super_clipboard.dart';

void main() {
  group('writeFormatForPath', () {
    test('matches every image_file_formats extension', () {
      expect(writeFormatForPath('/blobs/abc.png'), Formats.png);
      expect(writeFormatForPath('/blobs/abc.jpg'), Formats.jpeg);
      expect(writeFormatForPath('/blobs/abc.gif'), Formats.gif);
      expect(writeFormatForPath('/blobs/abc.webp'), Formats.webp);
      expect(writeFormatForPath('/blobs/abc.bmp'), Formats.bmp);
      expect(writeFormatForPath('/blobs/abc.tiff'), Formats.tiff);
    });

    test('is case-insensitive', () {
      expect(writeFormatForPath('/blobs/ABC.PNG'), Formats.png);
      expect(writeFormatForPath('/blobs/ABC.JPG'), Formats.jpeg);
    });

    test('falls back to png for an unrecognized extension', () {
      expect(writeFormatForPath('/blobs/abc.unknown'), Formats.png);
      expect(writeFormatForPath('/blobs/abc'), Formats.png);
    });
  });
}
