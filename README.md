# DocScan - Mobile Document Scanner & Enhancer (Flutter)

Modern, high-performance, cross-platform document scanner for **iOS** and **Android** built with Flutter. Ported and refined from the `smart-doc-scanner` desktop core pipeline.

---

## 🚀 Core Features

1. **Multi-Page Document Scanning & Import:**
   - Real-time camera viewfinder with frame alignment guides.
   - Batch multi-page scanning stream with active page count badge.
   - Multi-image gallery import.

2. **Corner Detection & Perspective Rectification:**
   - 4-point quadrilateral edge detection.
   - Interactive draggable corner handles for precise polygon adjustments.
   - Homography perspective warping into crisp flat rectangular pages.
   - Proportional margin expansion to preserve outer paper edges.
   - 90° lossless page rotation.

3. **Advanced Restoration & Enhancement Modes:**
   - **Magic Color (CamScanner style)**: Pure white paper background with vivid red seals, blue signatures, and highlighter colors.
   - **Clean White BG (`clean_bg`)**: Bleaches shadows and uneven lighting while maintaining stroke clarity.
   - **Sharp Text (`sharp_text`)**: High-contrast CLAHE & unsharp edge boost for faint pencil and low-ink prints.
   - **Restore Aged Paper (`restore_yellowed`)**: Neutralizes yellowing/foxing on old archival pages while preserving stamps.
   - **Remove Bleed-through (`remove_bleedthrough`)**: Suppresses ghost text showing through thin double-sided pages.
   - **Vivid Seal & Signature (`high_contrast_stamp`)**: Color space enhancement for official notary stamps and blue ballpoint pens.
   - **Thermal Receipt & POS (`super_sharp_mono`)**: Multi-scale background subtraction and Laplacian sharpening for thermal receipts.
   - **B&W Office Scan (`bw_scan`)**: Clean binarized scan for office printing.
   - **Natural Balanced**: True-to-life color reproduction.
   - Fine-tuning sliders: Shadow reduction, Sharpness, Contrast, and Brightness.
   - Hold-to-compare (Before vs After) view.

4. **Curved Paper & Wrinkle Flattening (Dewarping):**
   - Text flow vector analysis for unwrinkling creased pages and flattened book folds.

5. **Smart Auto-Naming:**
   - Regex-based document category classifier (Tax forms, Invoices, Contracts, IDs, Certificates, Receipts, etc.).
   - Clean slug suggestions with automated date stamping (`YYYY-MM-DD`).

6. **PDF Generation & Export:**
   - Multi-page standardized A4 PDF export with embedded compression.
   - Direct system print and share sheet (`share_plus`).

---

## 🛠️ Build & Run

### Prerequisites
- Flutter SDK `>= 3.0.0`
- Android Studio / Xcode

### Run on Android
```bash
flutter pub get
flutter run -d android
```

### Run on iOS
```bash
flutter pub get
cd ios && pod install && cd ..
flutter run -d ios
```
