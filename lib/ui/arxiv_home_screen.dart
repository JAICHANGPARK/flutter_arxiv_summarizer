import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'arxiv_home_screen.g.dart';

@Riverpod(keepAlive: true)
class GeminiApiKeyState extends _$GeminiApiKeyState {
  @override
  String build() {
    return "";
  }

  setValue(String s) {
    state = s;
  }
}

class ArxivPaper {
  final String title;
  final String authors;
  final String abstractText; // 초록 추가
  final String subjects;
  final String citeAs;
  final String submissionHistory; // 제출 기록 추가

  ArxivPaper({
    required this.title,
    required this.authors,
    required this.abstractText,
    required this.subjects,
    required this.citeAs,
    required this.submissionHistory,
  });

  // 디버깅을 위한 toString() 메소드
  @override
  String toString() {
    return 'Title: $title\n\n'
        'Authors: $authors\n\n'
        'Abstract: $abstractText\n\n'
        'Subjects: $subjects\n\n'
        'Cite As: $citeAs\n\n'
        'Submission History: $submissionHistory';
  }
}

Future<ArxivPaper> scrapeArxivPaper(String paperId) async {
  final url = Uri.parse('https://arxiv.org/abs/$paperId');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final document = parser.parse(response.body);

    // 1. 제목 (기존과 동일)
    final titleElement = document.querySelector('h1.title.mathjax');
    final title = titleElement?.text.replaceFirst('Title:', '').trim() ?? 'N/A';

    // 2. 저자 (기존과 동일)
    final authorsElement = document.querySelector('div.authors');
    final authors =
        authorsElement
            ?.querySelectorAll('a')
            .map((e) => e.text.trim())
            .join(', ') ??
        'N/A';

    // 3. 초록 (Abstract) 추출
    final abstractElement = document.querySelector(
      'blockquote.abstract.mathjax',
    );
    // 'Abstract:' 텍스트를 제거하고 앞뒤 공백을 정리합니다.
    final abstractText =
        abstractElement?.text.replaceFirst('Abstract:', '').trim() ?? 'N/A';

    // 4. 주제 (Subjects) (기존과 동일)
    final subjectsElement = document.querySelector('td.subjects');
    final subjects = subjectsElement?.text.trim() ?? 'N/A';

    // 5. Cite as (수정된 선택자)
    // metatable 안의 arxivid 클래스를 가진 첫 번째 table cell을 선택합니다.
    final citeAsElement = document.querySelector(
      '.metatable .tablecell.arxivid',
    );
    final citeAs = citeAsElement?.text.trim() ?? 'N/A';

    // 6. 제출 기록 (Submission History) 추출
    final historyElement = document.querySelector('div.submission-history');
    // 불필요한 "Submission history" 제목과 "From: ..." 부분을 정제할 수 있지만,
    // 우선은 전체 텍스트를 가져옵니다. 줄바꿈을 적용하여 가독성을 높입니다.
    final submissionHistory =
        historyElement?.text
            .replaceAll(RegExp(r'\s+'), ' ') // 여러 공백을 하나로
            .replaceAllMapped(
              RegExp(r'(\([0-9,]+ KB\))'),
              (match) => '${match.group(1)}\n',
            ) // 버전 정보 뒤에 줄바꿈 추가
            .trim() ??
        'N/A';

    return ArxivPaper(
      title: title,
      authors: authors,
      abstractText: abstractText,
      subjects: subjects,
      citeAs: citeAs,
      submissionHistory: submissionHistory,
    );
  } else {
    throw Exception('페이지를 로드할 수 없습니다: ${response.statusCode}');
  }
}

class GeminiApiService {
  Future<String?> translate(String apiKey, String text, String targetLanguage) async {

    if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY") {
      return 'API 키가 설정되지 않았습니다. 코드를 확인해 주세요.';
    }

    // Gemini API의 REST 엔드포인트 URL
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=$apiKey',
    );

    // API가 요구하는 헤더
    final headers = {'Content-Type': 'application/json'};

    // API가 요구하는 요청 본문(Body) 구조
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': 'Translate the following English text into $targetLanguage:\n\n$text'},
          ],
        },
      ],
    });

    try {
      // HTTP POST 요청 실행
      final response = await http.post(url, headers: headers, body: body);

      // 응답 처리
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        // Gemini API 응답 구조에 따라 결과 텍스트 추출
        // responseBody['candidates'][0]['content']['parts'][0]['text']
        final translatedText =
            responseBody['candidates'][0]['content']['parts'][0]['text'];

        return translatedText;
      } else {
        // API 에러 처리
        final errorBody = jsonDecode(response.body);
        print('API Error: ${response.statusCode}, Body: ${response.body}');
        return '번역 API 호출에 실패했습니다: ${errorBody['error']['message']}';
      }
    } catch (e) {
      // 네트워크 에러 등 기타 예외 처리
      print('네트워크 또는 기타 오류 발생: $e');
      return '번역 중 오류가 발생했습니다. 네트워크 연결을 확인해 주세요.';
    }
  }
}

class ArxivHomeScreen extends ConsumerStatefulWidget {
  const ArxivHomeScreen({super.key});

  @override
  ConsumerState<ArxivHomeScreen> createState() => _ArxivHomeScreenState();
}

class _ArxivHomeScreenState extends ConsumerState<ArxivHomeScreen> {
  TextEditingController textEditingController = TextEditingController();
  TextEditingController urlTextEditingController = TextEditingController();
  String? localPdfPath; // 다운로드된 PDF 파일의 로컬 경로
  bool isLoading = true;

  // arXiv URL에서 PDF를 다운로드하고 로컬 경로를 반환하는 함수
  Future<void> loadPdf(String paperId) async {
    // final paperId = pdfUrl.split("/").last;
    // final paperId = "https://arxiv.org/abs/$paperId";
    try {
      final url = 'https://arxiv.org/pdf/${paperId}.pdf';
      final response = await http.get(Uri.parse(url));

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$paperId.pdf');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      setState(() {
        localPdfPath = file.path;
        isLoading = false;
      });
    } catch (e) {
      // 오류 처리
      print("PDF 로드 중 오류 발생: $e");
      setState(() {
        isLoading = false;
      });
      // 사용자에게 오류 메시지를 보여줄 수 있습니다.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF를 불러올 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Arxiv Summarizer")),
      drawer: Drawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 16,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textEditingController,
                            decoration: InputDecoration(
                              labelText: "Gemini API Key",
                              hintText: "API KEY",
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            onEditingComplete: () {
                              if (textEditingController.text.isNotEmpty) {
                                final text = textEditingController.text.trim();
                                ref
                                    .read(geminiApiKeyStateProvider.notifier)
                                    .setValue(text.trim());
                              }
                            },
                            onSubmitted: (text) {
                              ref
                                  .read(geminiApiKeyStateProvider.notifier)
                                  .setValue(text.trim());
                            },

                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (textEditingController.text.isEmpty) {
                              return;
                            }
                            final text = textEditingController.text.trim();
                            ref
                                .read(geminiApiKeyStateProvider.notifier)
                                .setValue(text.trim());
                          },
                          child: Text("Set API KEY"),
                        ),
                      ],
                    ),

                  ),
                  Expanded(
                    child: Row(
                      spacing: 16,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: urlTextEditingController,
                            decoration: InputDecoration(
                              labelText: "Arxiv URL",
                              hintText:
                                  "URL (ex: https://arxiv.org/pdf/2505.17117)",
                              border: OutlineInputBorder(),
                            ),
                            onEditingComplete: () {},
                            onSubmitted: (text) {},
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (urlTextEditingController.text.isEmpty) {
                              return;
                            }
                            loadPdf(urlTextEditingController.text);
                          },
                          child: Text("Load Paper"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TabBar(
                              tabs: [
                                Tab(text: "PAPER INFOs"),
                                Tab(text: "PDF PREVIEW"),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  ArxivInfoPage(
                                    paperId: urlTextEditingController.text,
                                  ),
                                  Center(
                                    child: isLoading
                                        ? const CircularProgressIndicator() // 로딩 중일 때
                                        : localPdfPath != null
                                        ? PdfView(
                                            controller: PdfController(
                                              document: PdfDocument.openFile(
                                                localPdfPath!,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'PDF를 표시할 수 없습니다.',
                                          ), // 경로가 없을 때
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    VerticalDivider(),
                    Expanded(child: Placeholder()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArxivInfoPage extends StatelessWidget {
  final String paperId;

  const ArxivInfoPage({super.key, required this.paperId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArxivPaper>(
      future: scrapeArxivPaper(paperId), // 스크레이핑 함수 호출
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final paper = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _InfoTile(title: '논문 제목', content: paper.title),
                _InfoTile(title: '저자', content: paper.authors),
                _InfoTile(title: '주제 (Subjects)', content: paper.subjects),
                _InfoTile(title: 'Cite As (ID)', content: paper.citeAs),
                // 초록은 내용이 길 수 있으므로 selectable 하도록 만듭니다.
                // _InfoTile(
                //   title: '초록 (Abstract)',
                //   content: paper.abstractText,
                //   isSelectable: true,
                // ),
                // 기존 _InfoTile 대신 새로 만든 _AbstractTile 사용
                _AbstractTile(initialAbstract: paper.abstractText),
                _InfoTile(title: '주제 (Subjects)', content: paper.subjects),
                _InfoTile(title: '인용 (Cite as)', content: paper.citeAs),
                _InfoTile(
                  title: '제출 기록 (Submission History)',
                  content: paper.submissionHistory,
                ),
              ],
            ),
          );
        } else {
          return const Center(child: Text('데이터가 없습니다.'));
        }
      },
    );
  }
}

// 정보 표시용 재사용 위젯 (SelectableText 옵션 추가)
class _InfoTile extends StatelessWidget {
  final String title;
  final String content;
  final bool isSelectable;

  const _InfoTile({
    required this.title,
    required this.content,
    this.isSelectable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            isSelectable
                ? SelectableText(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  )
                : Text(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
          ],
        ),
      ),
    );
  }
}

// 기존 _InfoTile 대신 사용할 초록 전용 위젯
class _AbstractTile extends ConsumerStatefulWidget {
  final String initialAbstract;

  const _AbstractTile({required this.initialAbstract});

  @override
  _AbstractTileState createState() => _AbstractTileState();
}

class _AbstractTileState extends ConsumerState<_AbstractTile> {
  final GeminiApiService _geminiService = GeminiApiService();
  // TODO: 여기에 자신의 Gemini API 키를 입력하세요. (실제 앱에서는 보안 처리 필수!)


  // 상태 관리 변수 확장
  String _displayedAbstract = '';
  bool _isLoading = false;
  bool _isTranslated = false;

  // 번역 캐시 및 언어 선택 관련 변수
  final Map<String, String> _translationCache = {};
  String _selectedLanguage = 'Korean'; // 기본 선택 언어
  final List<String> _supportedLanguages = [
    'Korean', 'Japanese', 'Chinese', 'French', 'Spanish', 'German', 'Vietnamese'
  ];

  @override
  void initState() {
    super.initState();
    _displayedAbstract = widget.initialAbstract;
  }

  // 번역 실행 로직
  Future<void> _translate() async {
    setState(() {
      _isLoading = true;
    });

    String? result;

    // 1. 캐시 확인
    if (_translationCache.containsKey(_selectedLanguage)) {
      result = _translationCache[_selectedLanguage];
    } else {
      // 2. 캐시 없으면 API 호출
      result = await _geminiService.translate(
        ref.read(geminiApiKeyStateProvider),
        widget.initialAbstract,
        _selectedLanguage, // 선택된 언어를 전달
      );
      // 3. 결과 캐싱
      if (result != null) {
        _translationCache[_selectedLanguage] = result;
      }
    }

    setState(() {
      _displayedAbstract = result ?? '번역 실패';
      _isTranslated = true;
      _isLoading = false;
    });
  }

  // 원문 보기 로직
  void _showOriginal() {
    setState(() {
      _displayedAbstract = widget.initialAbstract;
      _isTranslated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "초록 (Abstract)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _displayedAbstract,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 12),
            // --- UI 컨트롤 부분 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. 언어 선택 드롭다운
                DropdownButton<String>(
                  value: _selectedLanguage,
                  underline: Container(height: 2, color: Theme.of(context).primaryColor),
                  items: _supportedLanguages.map((String language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLanguage = newValue!;
                      // 번역된 상태에서 언어를 바꾸면 바로 다시 번역
                      if (_isTranslated) {
                        _translate();
                      }
                    });
                  },
                ),
                const SizedBox(width: 16),
                // 2. 번역 / 원문 보기 버튼
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : (_isTranslated ? _showOriginal : _translate),
                  icon: _isLoading
                      ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(strokeWidth: 2.0),
                  )
                      : Icon(_isTranslated ? Icons.undo : Icons.translate),
                  label: Text(_isTranslated ? '원문 보기' : '번역하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}