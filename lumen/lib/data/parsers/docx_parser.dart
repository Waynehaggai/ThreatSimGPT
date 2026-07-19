import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';

/// Parses `.docx` (OpenXML) documents into metadata + reflowable [BookContent].
///
/// A DOCX is a zip of XML parts; this reads `word/document.xml` for the body and
/// `docProps/core.xml` for title/author — pure Dart (`archive` + `xml`), no
/// native code. Paragraph styles map to headings; numbered/bulleted paragraphs
/// group into list blocks.
class DocxParser implements DocumentParser {
  const DocxParser();

  @override
  Set<BookFormat> get supportedFormats => const {BookFormat.docx};

  @override
  Future<Result<DocumentMetadata>> extractMetadata(String filePath) async {
    try {
      final archive =
          ZipDecoder().decodeBytes(await File(filePath).readAsBytes());
      final core = _readXml(archive, 'docProps/core.xml');
      final doc = _readXml(archive, 'word/document.xml');

      final title = core?.findAllElements('title', namespace: '*').firstOrNull?.innerText;
      final author =
          core?.findAllElements('creator', namespace: '*').firstOrNull?.innerText;
      final words = doc == null
          ? 0
          : doc
              .findAllElements('t', namespace: '*')
              .fold<int>(0, (n, e) => n + e.innerText.split(RegExp(r'\s+')).length);

      return Result.success(DocumentMetadata(
        title: (title?.isNotEmpty ?? false)
            ? title!
            : p.basenameWithoutExtension(filePath),
        author: (author?.isNotEmpty ?? false) ? author! : 'Unknown',
        pageCount: (words / 300).ceil().clamp(1, 1 << 30),
      ));
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not read DOCX.', cause: e));
    }
  }

  @override
  Future<Result<BookContent>> extractContent(Book book) async {
    try {
      final archive =
          ZipDecoder().decodeBytes(await File(book.filePath).readAsBytes());
      final doc = _readXml(archive, 'word/document.xml');
      if (doc == null) {
        return const Result.failure(
            DocumentFailure('DOCX has no document body.'));
      }

      final blocks = <ContentBlock>[];
      var offset = 0;
      final pendingList = <String>[];

      void flushList() {
        if (pendingList.isEmpty) return;
        final text = pendingList.join('\n');
        blocks.add(ContentBlock(
            type: BlockType.list, text: text, charOffset: offset));
        offset += text.length + 1;
        pendingList.clear();
      }

      for (final para in doc.findAllElements('p', namespace: '*')) {
        final text = para
            .findAllElements('t', namespace: '*')
            .map((t) => t.innerText)
            .join()
            .trim();
        final style = _styleOf(para);
        final isList = _isListItem(para);

        if (isList) {
          if (text.isNotEmpty) pendingList.add(text);
          continue;
        }
        flushList();
        if (text.isEmpty) continue;

        if (style != null && style.toLowerCase().startsWith('heading')) {
          final level = int.tryParse(style.replaceAll(RegExp(r'\D'), '')) ?? 1;
          blocks.add(ContentBlock(
            type: BlockType.heading,
            text: text,
            level: (level - 1).clamp(0, 5),
            charOffset: offset,
          ));
        } else {
          blocks.add(ContentBlock(
              type: BlockType.paragraph, text: text, charOffset: offset));
        }
        offset += text.length + 1;
      }
      flushList();

      return Result.success(BookContent(
        bookId: book.id,
        chapters: [
          Chapter(id: 'ch-0', title: book.title, order: 0, blocks: blocks),
        ],
        generatedAt: DateTime.now(),
        wordCount: blocks.fold(0, (n, b) => n + (b.text?.split(' ').length ?? 0)),
      ));
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not parse DOCX.', cause: e));
    }
  }

  XmlDocument? _readXml(Archive archive, String path) {
    final file = archive.files.where((f) => f.name == path).firstOrNull;
    if (file == null) return null;
    return XmlDocument.parse(String.fromCharCodes(file.content as List<int>));
  }

  String? _styleOf(XmlElement para) => para
      .findAllElements('pStyle', namespace: '*')
      .firstOrNull
      ?.getAttribute('val', namespace: '*');

  bool _isListItem(XmlElement para) =>
      para.findAllElements('numPr', namespace: '*').isNotEmpty ||
      (_styleOf(para)?.toLowerCase().contains('listparagraph') ?? false);
}
