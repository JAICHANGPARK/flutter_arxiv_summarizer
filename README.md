# Arxiv Paper Summarizer with Gemini

A Flutter-based desktop application that leverages the powerful Gemini model to provide detailed summaries and translations of arXiv academic papers. This project uniquely utilizes the experimental **URL context feature** of the Gemini API (`gemini-2.5-flash-preview-05-20`) to perform comprehensive analysis directly from a paper's URL.

<img width="1712" alt="image" src="https://github.com/user-attachments/assets/c21619d7-bcc9-4a10-bb30-9c9e145adb98" />

<img width="1511" alt="image" src="https://github.com/user-attachments/assets/00ee137f-34fb-4106-8b0e-78d194d12925" />


---

## English

### Features

-   **Load arXiv Paper**: Fetch paper information and PDF by providing its ID or full URL.
-   **Detailed Summarization**: Utilizes the **Gemini 1.5 Flash** model with its **URL context feature** to read and analyze the entire PDF, generating a structured summary with key points and a detailed explanation.
-   **Multi-language Support**: Summaries and abstract translations can be generated in multiple languages (Korean, Japanese, Chinese, etc.).
-   **Side-by-Side View**: A clean two-panel UI to view paper metadata and the generated summary simultaneously.
-   **PDF Preview**: An integrated PDF viewer to read the original paper directly within the app.
-   **Web Scraping**: Scrapes essential metadata like title, authors, and subjects directly from the arXiv abstract page.
-   **Asynchronous State Management**: Built with **Riverpod (`AsyncNotifier`)** for robust and efficient handling of loading, data, and error states.

### Key Technologies Used

-   **Framework**: Flutter
-   **State Management**: Riverpod (featuring `AsyncNotifierProvider` for async operations)
--   **AI Model**: Google Gemini (`gemini-2.5-flash-preview-05-20`) via REST API
-   **Core AI Feature**: Experimental URL Context Tool
-   **Networking**: `http`
-   **HTML Parsing**: `html`
-   **PDF Viewing**: `pdfx`
-   **UI Rendering**: `flutter_markdown`

### Setup and Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/your-repository-name.git
    cd your-repository-name
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Generate Riverpod code:**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

4.  **Run the application:**
    ```bash
    flutter run
    ```

### How to Use

1.  Launch the application.
2.  Enter your Gemini API Key in the top-left input field and press "Set Key".
3.  Enter the arXiv paper ID (e.g., `2310.06825`) or the full URL in the top-right input field.
4.  Click "Load Paper". The paper's metadata and a PDF preview will be loaded.
5.  Select your desired language from the dropdown menu.
6.  Click the "요약하기" (Summarize) button to generate a full summary in the right-hand panel.
7.  Click the "번역하기" (Translate) button within the abstract card to translate only the abstract.

---

## 한국어

이 프로젝트는 강력한 Gemini 모델을 활용하여 arXiv 학술 논문의 상세한 요약과 번역을 제공하는 Flutter 기반 데스크톱 애플리케이션입니다. Gemini API의 실험적인 **URL 컨텍스트 기능**(`gemini-2.5-flash-preview-05-20`)을 활용하여 논문 URL로부터 직접 전체 내용을 심층 분석하는 것이 특징입니다.

### 주요 기능

-   **Arxiv 논문 로드**: 논문 ID 또는 전체 URL을 입력하여 논문 정보와 PDF를 불러옵니다.
-   **상세 요약 기능**: **Gemini 2.5 Flash** 모델의 **URL 컨텍스트 기능**을 활용하여 PDF 전체를 심층 분석하고, '핵심 포인트'와 '상세 요약'으로 구조화된 결과물을 생성합니다.
-   **다국어 지원**: 요약 및 초록 번역 결과를 한국어, 일본어, 중국어 등 다양한 언어로 생성할 수 있습니다.
-   **분할 화면 UI**: 논문 메타데이터와 생성된 요약문을 동시에 확인할 수 있는 깔끔한 2단 패널 레이아웃을 제공합니다.
-   **PDF 미리보기**: 앱 내에 통합된 PDF 뷰어로 원본 논문을 직접 읽을 수 있습니다.
-   **웹 스크레이핑**: Arxiv 초록 페이지에서 제목, 저자, 주제 등 핵심 메타데이터를 파싱하여 가져옵니다.
-   **비동기 상태 관리**: **Riverpod (`AsyncNotifier`)**를 사용하여 로딩, 데이터, 에러 상태를 효율적이고 안정적으로 관리합니다.

### 주요 사용 기술

-   **프레임워크**: Flutter
-   **상태 관리**: Riverpod (`AsyncNotifier`를 활용한 비동기 처리)
-   **AI 모델**: Google Gemini (`gemini-2.5-flash-preview-05-20`) REST API
-   **핵심 AI 기능**: 실험적인 URL 컨텍스트 도구
-   **네트워킹**: `http`
-   **HTML 파싱**: `html`
-   **PDF 뷰어**: `pdfx`
-   **UI 렌더링**: `flutter_markdown`

### 프로젝트 설정 및 설치

1.  **리포지토리 클론:**
    ```bash
    git clone https://github.com/your-username/your-repository-name.git
    cd your-repository-name
    ```

2.  **의존성 설치:**
    ```bash
    flutter pub get
    ```

3.  **Riverpod 코드 생성:**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

4.  **애플리케이션 실행:**
    ```bash
    flutter run
    ```

### 사용 방법

1.  애플리케이션을 실행합니다.
2.  좌측 상단 입력 필드에 Gemini API 키를 입력하고 "Set Key" 버튼을 누릅니다.
3.  우측 상단 입력 필드에 Arxiv 논문 ID(예: `2310.06825`) 또는 전체 URL을 입력합니다.
4.  "Load Paper" 버튼을 클릭하면 논문 정보와 PDF 미리보기가 로드됩니다.
5.  드롭다운 메뉴에서 원하는 언어를 선택합니다.
6.  "요약하기" 버튼을 클릭하면 우측 패널에 전체 논문 요약이 생성됩니다.
7.  초록 카드 안에 있는 "번역하기" 버튼을 누르면 초록만 번역됩니다.

---

### License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
