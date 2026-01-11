// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hadith_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HadithEditionEntry _$HadithEditionEntryFromJson(Map<String, dynamic> json) =>
    HadithEditionEntry(
      name: json['name'] as String,
      namear: json['namear'] as String?,
      collection: (json['collection'] as List<dynamic>)
          .map((e) => HadithCollection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$HadithEditionEntryToJson(HadithEditionEntry instance) =>
    <String, dynamic>{
      'name': instance.name,
      'namear': instance.namear,
      'collection': instance.collection,
    };

HadithCollection _$HadithCollectionFromJson(Map<String, dynamic> json) =>
    HadithCollection(
      id: json['id'] as String,
      language: json['language'] as String,
      link: json['link'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$HadithCollectionToJson(HadithCollection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'language': instance.language,
      'link': instance.link,
      'name': instance.name,
    };

HadithBook _$HadithBookFromJson(Map<String, dynamic> json) => HadithBook(
      metadata:
          HadithBookMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      hadiths: (json['hadiths'] as List<dynamic>)
          .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$HadithBookToJson(HadithBook instance) =>
    <String, dynamic>{
      'metadata': instance.metadata,
      'hadiths': instance.hadiths,
    };

HadithBookMetadata _$HadithBookMetadataFromJson(Map<String, dynamic> json) =>
    HadithBookMetadata(
      name: json['name'] as String,
      sections: Map<String, String>.from(json['sections'] as Map),
      sectionDetails: (json['section_details'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, SectionDetail.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$HadithBookMetadataToJson(HadithBookMetadata instance) =>
    <String, dynamic>{
      'name': instance.name,
      'sections': instance.sections,
      'section_details': instance.sectionDetails,
    };

SectionDetail _$SectionDetailFromJson(Map<String, dynamic> json) =>
    SectionDetail(
      hadithnumberFirst: json['hadithnumber_first'],
      hadithnumberLast: json['hadithnumber_last'],
      arabicnumberFirst: json['arabicnumber_first'],
      arabicnumberLast: json['arabicnumber_last'],
    );

Map<String, dynamic> _$SectionDetailToJson(SectionDetail instance) =>
    <String, dynamic>{
      'hadithnumber_first': instance.hadithnumberFirst,
      'hadithnumber_last': instance.hadithnumberLast,
      'arabicnumber_first': instance.arabicnumberFirst,
      'arabicnumber_last': instance.arabicnumberLast,
    };

Hadith _$HadithFromJson(Map<String, dynamic> json) => Hadith(
      hadithnumber: json['hadithnumber'],
      arabicnumber: json['arabicnumber'],
      text: json['text'] as String,
      grades: (json['grades'] as List<dynamic>?)
              ?.map((e) => HadithGrade.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reference: json['reference'] == null
          ? null
          : HadithReference.fromJson(json['reference'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HadithToJson(Hadith instance) => <String, dynamic>{
      'hadithnumber': instance.hadithnumber,
      'arabicnumber': instance.arabicnumber,
      'text': instance.text,
      'grades': instance.grades,
      'reference': instance.reference,
    };

HadithGrade _$HadithGradeFromJson(Map<String, dynamic> json) => HadithGrade(
      name: json['name'] as String,
      grade: json['grade'] as String,
    );

Map<String, dynamic> _$HadithGradeToJson(HadithGrade instance) =>
    <String, dynamic>{
      'name': instance.name,
      'grade': instance.grade,
    };

HadithReference _$HadithReferenceFromJson(Map<String, dynamic> json) =>
    HadithReference(
      book: (json['book'] as num).toInt(),
      hadith: (json['hadith'] as num).toInt(),
    );

Map<String, dynamic> _$HadithReferenceToJson(HadithReference instance) =>
    <String, dynamic>{
      'book': instance.book,
      'hadith': instance.hadith,
    };
