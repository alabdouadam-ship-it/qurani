import 'package:json_annotation/json_annotation.dart';

part 'hadith_model.g.dart';

@JsonSerializable()
class HadithEditionEntry {
  final String name;
  final String? namear;
  final List<HadithCollection> collection;

  HadithEditionEntry({
    required this.name,
    this.namear,
    required this.collection,
  });

  factory HadithEditionEntry.fromJson(Map<String, dynamic> json) =>
      _$HadithEditionEntryFromJson(json);

  Map<String, dynamic> toJson() => _$HadithEditionEntryToJson(this);
}

@JsonSerializable()
class HadithCollection {
  final String id;
  final String language; // "Arabic", "English", "French"
  final String link;
  final String? name; // Sometimes provided, but usually inferred from parent

  HadithCollection({
    required this.id,
    required this.language,
    required this.link,
    this.name,
  });

  factory HadithCollection.fromJson(Map<String, dynamic> json) =>
      _$HadithCollectionFromJson(json);

  Map<String, dynamic> toJson() => _$HadithCollectionToJson(this);

  bool get isArabic => language.toLowerCase() == 'arabic';
  bool get isEnglish => language.toLowerCase() == 'english';
  bool get isFrench => language.toLowerCase() == 'french';
}

@JsonSerializable()
class HadithBook {
  final HadithBookMetadata metadata;
  final List<Hadith> hadiths;

  HadithBook({
    required this.metadata,
    required this.hadiths,
  });

  factory HadithBook.fromJson(Map<String, dynamic> json) =>
      _$HadithBookFromJson(json);

  Map<String, dynamic> toJson() => _$HadithBookToJson(this);
}

@JsonSerializable()
class HadithBookMetadata {
  final String name;
  final Map<String, String> sections;
  @JsonKey(name: 'section_details')
  final Map<String, SectionDetail>? sectionDetails;

  HadithBookMetadata({
    required this.name,
    required this.sections,
    this.sectionDetails,
  });

  factory HadithBookMetadata.fromJson(Map<String, dynamic> json) =>
      _$HadithBookMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$HadithBookMetadataToJson(this);
}

@JsonSerializable()
class SectionDetail {
  @JsonKey(name: 'hadithnumber_first')
  final dynamic hadithnumberFirst; // Can be int or string sometimes? Stick to dynamic or int if consistent
  @JsonKey(name: 'hadithnumber_last')
  final dynamic hadithnumberLast;
  @JsonKey(name: 'arabicnumber_first')
  final dynamic arabicnumberFirst;
  @JsonKey(name: 'arabicnumber_last')
  final dynamic arabicnumberLast;

  SectionDetail({
    this.hadithnumberFirst,
    this.hadithnumberLast,
    this.arabicnumberFirst,
    this.arabicnumberLast,
  });

  factory SectionDetail.fromJson(Map<String, dynamic> json) =>
      _$SectionDetailFromJson(json);

  Map<String, dynamic> toJson() => _$SectionDetailToJson(this);
}

@JsonSerializable()
class Hadith {
  final dynamic hadithnumber; 
  final dynamic arabicnumber;
  final String text;
  final List<HadithGrade> grades;
  final HadithReference? reference;

  Hadith({
    required this.hadithnumber,
    required this.arabicnumber,
    required this.text,
    this.grades = const [],
    this.reference,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) =>
      _$HadithFromJson(json);

  Map<String, dynamic> toJson() => _$HadithToJson(this);
}

@JsonSerializable()
class HadithGrade {
  final String name;
  final String grade;

  HadithGrade({
    required this.name,
    required this.grade,
  });

  factory HadithGrade.fromJson(Map<String, dynamic> json) =>
      _$HadithGradeFromJson(json);

  Map<String, dynamic> toJson() => _$HadithGradeToJson(this);
}

@JsonSerializable()
class HadithReference {
  final int book;
  final int hadith;

  HadithReference({
    required this.book,
    required this.hadith,
  });

  factory HadithReference.fromJson(Map<String, dynamic> json) =>
      _$HadithReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$HadithReferenceToJson(this);
}
