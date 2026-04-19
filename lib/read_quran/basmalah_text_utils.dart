/// Strips a leading Basmalah ("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ") from
/// [text] and returns the remainder, or `null` if the text does not begin
/// with a full Basmalah. Tolerates Uthmani vs. simple script differences
/// by matching the skeleton of base letters (ignoring diacritics) and
/// accepting either Alif-Wasla (ٱ) or standard Alif (ا).
///
/// Previously the top-level private `_removeBasmalah` in
/// `read_quran_screen.dart`.
String? removeBasmalah(String text) {
  bool isArabicLetter(int codeUnit) {
    if (codeUnit >= 0x0621 && codeUnit <= 0x064A) {
      return true; // Standard letters
    }
    if (codeUnit == 0x0671) return true; // Alif Wasla (ٱ)
    return false;
  }

  // Skeleton of Basmalah letters (بسم الله الرحمن الرحيم) — base letters
  // only, no diacritics. Uthmani script uses Alif-Wasla (0x0671) where
  // simple script uses standard Alif (0x0627); we accept either below.
  const expectedSkeleton = [
    0x0628, 0x0633, 0x0645, // B S M
    0x0671, 0x0644, 0x0644, 0x0647, // A L L H (Alif Wasla)
    0x0671, 0x0644, 0x0631, 0x062D, 0x0645, 0x0646, // A L R H M N
    0x0671, 0x0644, 0x0631, 0x062D, 0x064A, 0x0645, // A L R H Y M
  ];

  int skeletonIndex = 0;
  int originalIndex = 0;

  while (
      originalIndex < text.length && skeletonIndex < expectedSkeleton.length) {
    final code = text.codeUnitAt(originalIndex);

    if (code == expectedSkeleton[skeletonIndex] ||
        (expectedSkeleton[skeletonIndex] == 0x0671 && code == 0x0627)) {
      skeletonIndex++;
      originalIndex++;
    } else if (!isArabicLetter(code)) {
      // Skip diacritics / spaces / symbols in original text.
      originalIndex++;
    } else {
      // Mismatch in base letter — not a Basmalah.
      return null;
    }
  }

  if (skeletonIndex == expectedSkeleton.length) {
    return text.substring(originalIndex).trim();
  }

  return null; // Partial match or not found
}
