import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'arxiv_home_screen.g.dart';

// --- 1. Riverpod Providers ---

@Riverpod(keepAlive: true)
class GeminiApiKeyState extends _$GeminiApiKeyState {
  @override
  String build() => "";

  void setValue(String s) => state = s;
}

@riverpod
class SummarizedResult extends _$SummarizedResult {
  @override
  FutureOr<String> build() => '';

  Future<void> summarizePaper({
    required String paperId,
    required String subjects,
    required String targetLanguage,
  }) async {
    state = const AsyncLoading();
    final geminiApiService = GeminiApiService();
    final apiKey = ref.read(geminiApiKeyStateProvider);

    state = await AsyncValue.guard(() async {
      return await geminiApiService.summarizePaper(
            apiKey,
            paperId,
            subjects,
            targetLanguage,
          ) ??
          '요약 생성에 실패했습니다.';
    });
  }
}

// --- 2. Data Model & Services ---

class ArxivPaper {
  final String title,
      authors,
      abstractText,
      subjects,
      citeAs,
      submissionHistory;

  ArxivPaper({
    required this.title,
    required this.authors,
    required this.abstractText,
    required this.subjects,
    required this.citeAs,
    required this.submissionHistory,
  });
}

Future<ArxivPaper> scrapeArxivPaper(String paperId) async {
  if (paperId.isEmpty) {
    return ArxivPaper(
      title: 'N/A',
      authors: 'N/A',
      abstractText: 'N/A',
      subjects: 'N/A',
      citeAs: 'N/A',
      submissionHistory: 'N/A',
    );
  }
  final url = Uri.parse('https://arxiv.org/abs/$paperId');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final document = parser.parse(response.body);
    return ArxivPaper(
      title:
          document
              .querySelector('h1.title.mathjax')
              ?.text
              .replaceFirst('Title:', '')
              .trim() ??
          'N/A',
      authors:
          document
              .querySelector('div.authors')
              ?.querySelectorAll('a')
              .map((e) => e.text.trim())
              .join(', ') ??
          'N/A',
      abstractText:
          document
              .querySelector('blockquote.abstract.mathjax')
              ?.text
              .replaceFirst('Abstract:', '')
              .trim() ??
          'N/A',
      subjects: document.querySelector('td.subjects')?.text.trim() ?? 'N/A',
      citeAs:
          document
              .querySelector('.metatable .tablecell.arxivid')
              ?.text
              .trim() ??
          'N/A',
      submissionHistory:
          document
              .querySelector('div.submission-history')
              ?.text
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAllMapped(
                RegExp(r'(\([0-9,]+ KB\))'),
                (match) => '${match.group(1)}\n',
              )
              .trim() ??
          'N/A',
    );
  } else {
    throw Exception('페이지를 로드할 수 없습니다: ${response.statusCode}');
  }
}

class GeminiApiService {
  final modelName = "gemini-2.5-flash-preview-05-20";

  Future<String?> translate(
    String apiKey,
    String text,
    String targetLanguage,
    String subjects,
  ) async {
    if (apiKey.isEmpty) return 'API 키가 설정되지 않았습니다.';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final prompt =
        """
    **Your Role:** You are a professional translator with expertise in the academic fields specified below.
    **Context:** The paper is from a paper with these subjects: "$subjects".
    **Task:** Translate the abstract into high-quality, academic $targetLanguage.
    **Instructions:**
    1. Pay very close attention to the specified subjects to use the correct terminology.
    2. Translate all technical terms and jargon accurately.
    3. The tone must be formal and suitable for researchers.
    **Original English Abstract:**
    "$text"
    """;
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        return jsonDecode(
          response.body,
        )['candidates'][0]['content']['parts'][0]['text'];
      }
      return '번역 API 호출 실패: ${jsonDecode(response.body)['error']['message']}';
    } catch (e) {
      return '번역 중 오류 발생: $e';
    }
  }

  Future<String?> summarizePaper(
    String apiKey,
    String paperId,
    String subjects,
    String targetLanguage,
  ) async {
    if (apiKey.isEmpty) return 'API 키가 설정되지 않았습니다.';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final prompt =
        """
    **Your Role:** You are a meticulous AI research analyst. Your primary task is to perform a **comprehensive analysis** of the **entire academic paper** located at the URL provided and then generate a detailed, structured summary.
    **Source Document URL:** https://arxiv.org/pdf/$paperId
    **Context:** The paper is in the fields of: "$subjects".
    **Analysis and Summarization Instructions:**
    1.  **Full Document Analysis:** You MUST access and analyze the **entire content** of the PDF at the URL, from the introduction to the final conclusion. Do not merely summarize the abstract.
    2.  **Section-Specific Focus:** Pay close attention to the following sections: **Introduction** (for the problem), **Methodology** (for the techniques), **Results/Experiments** (for the findings), and **Conclusion** (for the implications).
    3.  **Detailed Summary Requirement:** The 'Detailed Summary' must be substantial and detailed, **at least 3-4 paragraphs long**.
    **Output Format (Strictly follow in $targetLanguage):**
    **Part 1: Key Points**
    - Create a heading titled "핵심 포인트".
    - Under it, provide exactly three bullet points synthesizing the most critical information.
    **Part 2: Detailed Summary**
    - Create a heading titled "상세 요약".
    - Under it, provide the comprehensive, multi-paragraph summary as instructed.
    """;
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      "tools": [
        {"url_context": {}},
      ],
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        return jsonDecode(
          response.body,
        )['candidates'][0]['content']['parts'][0]['text'];
      }
      return '요약 API 호출 실패: ${jsonDecode(response.body)['error']['message']}';
    } catch (e) {
      return '요약 중 오류 발생: $e';
    }
  }
}

// --- 3. UI Widgets ---

class ArxivHomeScreen extends ConsumerStatefulWidget {
  const ArxivHomeScreen({super.key});

  @override
  ConsumerState<ArxivHomeScreen> createState() => _ArxivHomeScreenState();
}

class _ArxivHomeScreenState extends ConsumerState<ArxivHomeScreen> {
  final _apiKeyController = TextEditingController();
  final _urlController = TextEditingController();
  String _paperId = '';
  String? _localPdfPath;
  bool _isPdfLoading = false;

  void _loadPaper() async {
    final urlText = _urlController.text.trim();
    if (urlText.isEmpty) return;

    final id = urlText.split('/').last;
    setState(() {
      _paperId = id;
      _isPdfLoading = true;
      _localPdfPath = null;
    });

    try {
      final url = 'https://arxiv.org/pdf/$id.pdf';
      final response = await http.get(Uri.parse(url));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$id.pdf');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      setState(() => _localPdfPath = file.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 로드 실패: $e')));
    } finally {
      setState(() => _isPdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Arxiv Summarizer")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: "Gemini API Key",
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onSubmitted: (key) => ref
                        .read(geminiApiKeyStateProvider.notifier)
                        .setValue(key),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => ref
                      .read(geminiApiKeyStateProvider.notifier)
                      .setValue(_apiKeyController.text),
                  child: const Text("Set Key"),
                ),
                const SizedBox(width: 16),
                Expanded(child: TabBar(tabs: [],)),
              ],
            ),
            const Divider(height: 32),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _urlController,
                                  decoration: const InputDecoration(
                                    labelText: "Arxiv Paper ID or URL",
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _loadPaper(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _loadPaper,
                                child: const Text("Load Paper"),
                              ),
                            ],
                          ),

                          const TabBar(
                            tabs: [
                              Tab(text: "PAPER INFO"),
                              Tab(text: "PDF PREVIEW"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                if (_paperId.isNotEmpty)
                                  ArxivInfoPage(paperId: _paperId)
                                else
                                  const Center(
                                    child: Text(
                                      "Load a paper to see its info.",
                                    ),
                                  ),
                                _isPdfLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _localPdfPath != null
                                    ? PdfView(
                                        controller: PdfController(
                                          document: PdfDocument.openFile(
                                            _localPdfPath!,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Text('PDF will be shown here.'),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 32),
                  Expanded(
                    flex: 3,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final summaryAsync = ref.watch(
                          summarizedResultProvider,
                        );
                        return summaryAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, st) =>
                              Center(child: SelectableText('Error: $err')),
                          data: (summary) {
                            if (summary.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Summary will appear here.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }
                            return Markdown(data: summary, selectable: true);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArxivInfoPage extends ConsumerStatefulWidget {
  final String paperId;

  const ArxivInfoPage({super.key, required this.paperId});

  @override
  ConsumerState<ArxivInfoPage> createState() => _ArxivInfoPageState();
}

class _ArxivInfoPageState extends ConsumerState<ArxivInfoPage> {
  String _selectedLanguage = 'Korean';
  final _supportedLanguages = [
    'Korean',
    'Japanese',
    'Chinese',
    'French',
    'Spanish',
    'German',
  ];

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(summarizedResultProvider);
    return FutureBuilder<ArxivPaper>(
      future: scrapeArxivPaper(widget.paperId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to scrape paper info: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No data found.'));
        }

        final paper = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    items: _supportedLanguages
                        .map(
                          (lang) =>
                              DropdownMenuItem(value: lang, child: Text(lang)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLanguage = value!),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: summaryAsync.isLoading
                        ? null
                        : () => ref
                              .read(summarizedResultProvider.notifier)
                              .summarizePaper(
                                paperId: widget.paperId,
                                subjects: paper.subjects,
                                targetLanguage: _selectedLanguage,
                              ),
                    icon: summaryAsync.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.summarize),
                    label: const Text('요약하기'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: [
                  _InfoTile(title: '논문 제목', content: paper.title),
                  _InfoTile(title: '저자', content: paper.authors),
                  _AbstractTile(
                    initialAbstract: paper.abstractText,
                    subjects: paper.subjects,
                    selectedLanguage: _selectedLanguage,
                  ),
                  _InfoTile(title: '주제 (Subjects)', content: paper.subjects),
                  _InfoTile(title: '인용 (Cite as)', content: paper.citeAs),
                  _InfoTile(title: '제출 기록', content: paper.submissionHistory),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String content;

  const _InfoTile({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(content),
          ],
        ),
      ),
    );
  }
}

class _AbstractTile extends ConsumerStatefulWidget {
  final String initialAbstract, subjects, selectedLanguage;

  const _AbstractTile({
    required this.initialAbstract,
    required this.subjects,
    required this.selectedLanguage,
  });

  @override
  ConsumerState<_AbstractTile> createState() => _AbstractTileState();
}

class _AbstractTileState extends ConsumerState<_AbstractTile> {
  final _translationCache = <String, String>{};
  String _displayedAbstract = '';
  bool _isLoading = false;
  bool _isTranslated = false;

  @override
  void initState() {
    super.initState();
    _displayedAbstract = widget.initialAbstract;
  }

  @override
  void didUpdateWidget(covariant _AbstractTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLanguage != oldWidget.selectedLanguage &&
        _isTranslated) {
      _translate();
    }
  }

  Future<void> _translate() async {
    setState(() => _isLoading = true);
    final targetLang = widget.selectedLanguage;
    String? result;

    if (_translationCache.containsKey(targetLang)) {
      result = _translationCache[targetLang];
    } else {
      final geminiApi = GeminiApiService();
      result = await geminiApi.translate(
        ref.read(geminiApiKeyStateProvider),
        widget.initialAbstract,
        targetLang,
        widget.subjects,
      );
      if (result != null) _translationCache[targetLang] = result;
    }
    setState(() {
      _displayedAbstract = result ?? '번역 실패';
      _isTranslated = true;
      _isLoading = false;
    });
  }

  void _showOriginal() => setState(() {
    _displayedAbstract = widget.initialAbstract;
    _isTranslated = false;
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "초록 (Abstract)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _displayedAbstract,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_isTranslated ? _showOriginal : _translate),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isTranslated ? Icons.undo : Icons.translate),
                label: Text(
                  _isTranslated ? '원문 보기' : '번역하기 (${widget.selectedLanguage})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
