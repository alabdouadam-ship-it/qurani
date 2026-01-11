import 'package:flutter/material.dart';

class ChapterTranslationService {
  // Map<EnglishTitle, Map<LanguageCode, TranslatedTitle>>
  static final Map<String, Map<String, String>> _dictionary = {
    // Sahih Bukhari / Muslim Common Books
    "Revelation": {
      "ar": "بدء الوحي",
      "fr": "La Révélation"
    },
    "Belief": {
      "ar": "الإيمان",
      "fr": "La Foi"
    },
    "The Book of Faith": {
      "ar": "كتاب الإيمان",
      "fr": "Le Livre de la Foi"
    },
    "Knowledge": {
      "ar": "العلم",
      "fr": "Le Savoir"
    },
    "Ablutions (Wudu')": {
      "ar": "الوضوء",
      "fr": "Les Ablutions (Wudu')"
    },
    "Bathing (Ghusl)": {
      "ar": "الغسل",
      "fr": "Le Bain (Ghusl)"
    },
    "Menstrual Periods": {
      "ar": "الحيض",
      "fr": "Les Menstrues"
    },
    "Rubbing hands and feet with dust (Tayammum)": {
      "ar": "التييم",
      "fr": "Le Tayammum"
    },
    "Prayers (Salat)": {
      "ar": "الصلاة",
      "fr": "La Prière (Salat)"
    },
    "The Book of Prayers": {
      "ar": "كتاب الصلاة",
      "fr": "Le Livre de la Prière"
    },
    "Times of the Prayers": {
      "ar": "مواقيت الصلاة",
      "fr": "Les horaires de prière"
    },
    "Call to Prayers (Adhaan)": {
      "ar": "الأذان",
      "fr": "L'Appel à la Prière (Adhan)"
    },
    "Friday Prayer": {
      "ar": "الجمعة",
      "fr": "La Prière du Vendredi"
    },
    "Fear Prayer": {
      "ar": "صلاة الخوف",
      "fr": "La Prière de la Peur"
    },
    "The Two Festivals (Eids)": {
      "ar": "العيدين",
      "fr": "Les Deux Fêtes (Aïd)"
    },
    "Witr Prayer": {
      "ar": "الوتر",
      "fr": "La Prière du Witr"
    },
    "Invoking Allah for Rain (Istisqaa)": {
      "ar": "الاستسقاء",
      "fr": "L'Invocation pour la Pluie"
    },
    "Eclipses": {
      "ar": "الكسوف",
      "fr": "Les Éclipses"
    },
    "Prostration During Recital of Qur'an": {
      "ar": "سجود القرآن",
      "fr": "La Prosternation (Lecture du Coran)"
    },
    "Shortening the Prayers (At-Taqseer)": {
      "ar": "التقصير",
      "fr": "Le Raccourcissement des Prières"
    },
    "Prayer at Night (Tahajjud)": {
      "ar": "التهجد",
      "fr": "La Prière Nocturne (Tahajjud)"
    },
    "Funerals (Al-Janaa'iz)": {
      "ar": "الجنائز",
      "fr": "Les Funérailles"
    },
    "Obligatory Charity Tax (Zakat)": {
      "ar": "الزكاة",
      "fr": "La Zakât"
    },
    "The Book of Zakat": {
      "ar": "كتاب الزكاة",
      "fr": "Le Livre de la Zakât"
    },
    "Hajj (Pilgrimage)": {
      "ar": "الحج",
      "fr": "Le Pèlerinage (Hajj)"
    },
    "The Book of Pilgrimage": {
      "ar": "كتاب الحج",
      "fr": "Le Livre du Pèlerinage"
    },
    "`Umrah (Minor pilgrimage)": {
      "ar": "العمرة",
      "fr": "La Omra"
    },
    "Fasting": {
      "ar": "الصوم",
      "fr": "Le Jeûne"
    },
    "The Book of Fasting": {
      "ar": "كتاب الصيام",
      "fr": "Le Livre du Jeûne"
    },
    "Before Day of Judgment": {
        "ar": "أشراط الساعة",
        "fr": "Signes de l'Heure"
    },
    "Sales and Trade": {
      "ar": "البيوع",
      "fr": "Les Ventes"
    },
    "Hiring": {
      "ar": "الإجارة",
      "fr": "La Location"
    },
    "Transferance of a Debt from One Person to Another (Al-Hawaala)": {
      "ar": "الحوالة",
      "fr": "Le Transfert de Dette (Hawala)"
    },
    "Representation, Authorization, Business by Proxy": {
      "ar": "الوكالة",
      "fr": "La Procuration (Wakalah)"
    },
    "Agriculture": {
      "ar": "المزارعة",
      "fr": "L'Agriculture"
    },
    "Distribution of Water": {
      "ar": "المساقات",
      "fr": "La Distribution de l'Eau"
    },
    "Loans, Payment of Loans, Freezing of Property, Bankruptcy": {
      "ar": "الاستقراض",
      "fr": "Les Prêts et Faillites"
    },
    "Lost Things Picked up by Someone (Luqatah)": {
      "ar": "اللقطة",
      "fr": "Objets Trouvés (Luqata)"
    },
    "Oppressions": {
      "ar": "المظالم",
      "fr": "Les Injustices (Mazalim)"
    },
    "Partnership": {
      "ar": "الشركة",
      "fr": "Le Partenariat"
    },
    "Mortgaging": {
      "ar": "الرهن",
      "fr": "L'Hypothèque"
    },
    "Manumission of Slaves": {
      "ar": "العتق",
      "fr": "L'Affranchissement"
    },
    "Gifts": {
      "ar": "الهبة",
      "fr": "Les Dons"
    },
    "Witnesses": {
      "ar": "الشهادات",
      "fr": "Les Témoignages"
    },
    "Peacemaking": {
      "ar": "الصلح",
      "fr": "La Réconciliation"
    },
    "Conditions": {
      "ar": "الشروط",
      "fr": "Les Conditions"
    },
    "Wills and Testaments (Wasaayaa)": {
      "ar": "الوصايا",
      "fr": "Les Testaments"
    },
    "The Book of Wills": {
      "ar": "كتاب الوصايا",
      "fr": "Le Livre des Testaments"
    },
    "Fighting for the Cause of Allah (Jihaad)": {
      "ar": "الجهاد",
      "fr": "Le Jihad"
    },
    "The Book of Jihad": {
      "ar": "كتاب الجهاد",
      "fr": "Le Livre du Jihad"
    },
    "One-fifth of Booty to the Cause of Allah (Khumus)": {
      "ar": "فرض الخمس",
      "fr": "Le Khumus"
    },
    "Beginning of Creation": {
      "ar": "بدء الخلق",
      "fr": "Le Début de la Création"
    },
    "Prophets": {
      "ar": "الأنبياء",
      "fr": "Les Prophètes"
    },
    "Virtues and Merits of the Prophet (pbuh) and his Companions": {
      "ar": "المناقب",
      "fr": "Les Vertus"
    },
    "Companions of the Prophet": {
      "ar": "فضائل الصحابة",
      "fr": "Les Compagnons"
    },
    "Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)": {
      "ar": "المغازي",
      "fr": "Les Expéditions Militaires (Maghazi)"
    },
    "Virtues of the Qur'an": {
      "ar": "فضائل القرآن",
      "fr": "Les Vertus du Coran"
    },
    "Wedlock, Marriage (Nikaah)": {
      "ar": "النكاح",
      "fr": "Le Mariage (Nikah)"
    },
    "The Book of Marriage": {
      "ar": "كتاب النكاح",
      "fr": "Le Livre du Mariage"
    },
    "Divorce": {
      "ar": "الطلاق",
      "fr": "Le Divorce"
    },
    "The Book of Divorce": {
      "ar": "كتاب الطلاق",
      "fr": "Le Livre du Divorce"
    },
    "Food, Meals": {
      "ar": "الأطعمة",
      "fr": "La Nourriture"
    },
    "Sacrifice on Occasion of Birth (`Aqiqa)": {
      "ar": "العقيقة",
      "fr": "La 'Aqiqah"
    },
    "Hunting, Slaughtering": {
      "ar": "الذبائح والصيد",
      "fr": "La Chasse et l'Abattage"
    },
    "Al-Adha Festival Sacrifice (Adaahi)": {
      "ar": "الأضاحي",
      "fr": "Le Sacrifice (Adha)"
    },
    "Drinks": {
      "ar": "الأشربة",
      "fr": "Les Boissons"
    },
    "Patients": {
      "ar": "المرضى",
      "fr": "Les Malades"
    },
    "Medicine": {
      "ar": "الطب",
      "fr": "La Médecine"
    },
    "Dress": {
      "ar": "اللباس",
      "fr": "L'Habillement"
    },
    "Good Manners and Form (Al-Adab)": {
      "ar": "الأدب",
      "fr": "Les Bonnes Manières"
    },
    "Asking Permission": {
      "ar": "الاستئذان",
      "fr": "La permission"
    },
    "Invocations": {
      "ar": "الدعوات",
      "fr": "Les Invocations"
    },
    "Divine Will (Al-Qadar)": {
      "ar": "القدر",
      "fr": "Le Destin (Qadar)"
    },
    "The Book of Destiny": {
      "ar": "كتاب القدر",
      "fr": "Le Livre du Destin"
    },
    "Oaths and Vows": {
      "ar": "الأيمان والنذور",
      "fr": "Les Serments et Vœux"
    },
    "Expiation for Unfulfilled Oaths": {
      "ar": "كفارة الأيمان",
      "fr": "L'Expiation des Serments"
    },
    "Laws of Inheritance (Al-Fara'id)": {
      "ar": "الفرائض",
      "fr": "L'Héritage (Fara'id)"
    },
    "Limits and Punishments set by Allah (Hudood)": {
      "ar": "الحدود",
      "fr": "Les Peines (Hudud)"
    },
    "Blood Money (Ad-Diyat)": {
      "ar": "الديات",
      "fr": "Le Prix du Sang (Diyat)"
    },
    "Apostates": {
      "ar": "استتابة المرتد",
      "fr": "L'Apostalsie"
    },
    "(Statements made under) Coercion": {
      "ar": "الإكراه",
      "fr": "La Contrainte"
    },
    "Tricks": {
      "ar": "الحِيَل",
      "fr": "Les Ruses (Hiyam)"
    },
    "Interpretation of Dreams": {
      "ar": "التعبير",
      "fr": "L'Interprétation des Rêves"
    },
    "Afflictions and the End of the World": {
      "ar": "الفتن",
      "fr": "Les Troubles (Fitan)"
    },
    "Judgments (Ahkaam)": {
      "ar": "الأحكام",
      "fr": "Les Jugements"
    },
    "Wishes": {
      "ar": "التمني",
      "fr": "Les Souhaits"
    },
    "Accepting Information Given by a Truthful Person": {
      "ar": "أخبار الآحاد",
      "fr": "L'Information Unique"
    },
    "Holding Fast to the Qur'an and Sunnah": {
      "ar": "الاعتصام بالكتاب والسنة",
      "fr": "S'accrocher au Coran et à la Sunna"
    },
    "Oneness, Uniqueness of Allah (Tawheed)": {
      "ar": "التوحيد",
      "fr": "L'Unicité (Tawhid)"
    },
    // Missing Sahih Bukhari Chapters
    "Virtues of Prayer at Masjid Makkah and Madinah": {
      "ar": "فضل الصلاة في مسجد مكة والمدينة",
      "fr": "Les mérites de la prière à la Mosquée de La Mecque et Médine"
    },
    "Actions while Praying": {
      "ar": "العمل في الصلاة",
      "fr": "Les actions pendant la prière"
    },
    "Pilgrims Prevented from Completing the Pilgrimage": {
      "ar": "المحصر",
      "fr": "Le pèlerin empêché (Muhsar)"
    },
    "Penalty of Hunting while on Pilgrimage": {
      "ar": "جزاء الصيد",
      "fr": "La compensation de la chasse"
    },
    "Virtues of Madinah": {
      "ar": "فضائل المدينة",
      "fr": "Les vertus de Médine"
    },
    "Praying at Night in Ramadaan (Taraweeh)": {
      "ar": "صلاة التراويح",
      "fr": "La prière de nuit (Tarawih)"
    },
    "Virtues of the Night of Qadr": {
      "ar": "فضل ليلة القدر",
      "fr": "Les mérites de la Nuit du Destin"
    },
    "Retiring to a Mosque for Remembrance of Allah (I'tikaf)": {
      "ar": "الاعتكاف",
      "fr": "La retraite spirituelle (I'tikaf)"
    },
    "Sales in which a Price is paid for Goods to be Delivered Later (As-Salam)": {
      "ar": "السلم",
      "fr": "La vente Salam"
    },
    "Shuf'a": {
      "ar": "الشفعة",
      "fr": "La préemption (Shuf'a)"
    },
    "Kafalah": {
      "ar": "الكفالة",
      "fr": "Le cautionnement"
    },
    "Khusoomaat": {
      "ar": "الخصومات",
      "fr": "Les litiges"
    },
    "Makaatib": {
      "ar": "المكاتب",
      "fr": "Le contrat d'écriture (Mukataba)"
    },
    "Jizyah and Mawaada'ah": {
      "ar": "الجزية والموادعة",
      "fr": "La Jizya et la Trêve"
    },
    "Merits of the Helpers in Madinah (Ansaar)": {
      "ar": "مناقب الأنصار",
      "fr": "Les mérites des Ansar"
    },
    "Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh))": {
      "ar": "تفسير القرآن",
      "fr": "L'exégèse du Prophète (Tafsir)"
    },
    "Supporting the Family": {
      "ar": "النفقات",
      "fr": "Les dépenses (Nafaqa)"
    },
    "To make the Heart Tender (Ar-Riqaq)": {
      "ar": "الرقاق",
      "fr": "L'attendrissement des cœurs"
    },
    "Laws of Inheritance (Al-Faraa'id)": { // JSON Variant spelling
       "ar": "الفرائض",
       "fr": "L'Héritage (Fara'id)"
    },

    // Islamic Terms / Variations
    "The Book Of Purification": {
      "ar": "كتاب الطهارت",
      "fr": "Le Livre de la Purification"
    },
    "Purification (Kitab Al-Taharah)": {
      "ar": "كتاب الطهارة",
      "fr": "Purification (Taharah)"
    },
    "Prayer (Kitab Al-Salat)": {
       "ar": "كتاب الصلاة",
       "fr": "Prière (Salat)"
    },
    "Zakat (Kitab Al-Zakat)": {
        "ar": "كتاب الزكاة",
        "fr": "Zakât"
    },
    "The Rites of Hajj (Kitab Al-Manasik Wa'l-Hajj)": {
        "ar": "كتاب المناسك",
        "fr": "Rites du Hajj"
    },
    "Marriage (Kitab Al-Nikah)": {
         "ar": "كتاب النكاح",
         "fr": "Mariage"
    },
    "Divorce (Kitab Al-Talaq)": {
        "ar": "كتاب الطلاق",
         "fr": "Divorce"
    },
    "Fasting (Kitab Al-Siyam)": {
        "ar": "كتاب الصيام",
         "fr": "Jeûne"
    },
    "Jihad (Kitab Al-Jihad)": {
        "ar": "كتاب الجهاد",
         "fr": "Jihad"
    },
    "Commercial Transactions (Kitab Al-Buyu)": {
        "ar": "كتاب البيوع",
        "fr": "Transactions Commerciales"
    },
    "The Book of Business": {
        "ar": "كتاب البيوع",
        "fr": "Transactions Commerciales"
    },
    // --- MAPPINGS FOR SAHIH MUSLIM ---
    "Introduction": {
      "ar": "المقدمة",
      "fr": "Introduction"
    },
    "The Book of Menstruation": {
      "ar": "كتاب الحيض",
      "fr": "Le Livre des Menstrues"
    },
    "The Book of Mosques and Places of Prayer": {
      "ar": "كتاب المساجد ومواضع الصلاة",
      "fr": "Le Livre des Mosquées"
    },
    "The Book of Prayer - Travellers": {
      "ar": "كتاب صلاة المسافرين وقصرها",
      "fr": "Prière des Voyageurs"
    },
    "The Book of Prayer - Friday": {
      "ar": "كتاب الجمعة",
      "fr": "Prière du Vendredi"
    },
    "The Book of Prayer - Two Eids": {
      "ar": "كتاب صلاة العيدين",
      "fr": "Prière des Deux Fêtes"
    },
    "The Book of Prayer - Rain": {
      "ar": "كتاب صلاة الاستسقاء",
      "fr": "Prière pour la Pluie"
    },
    "The Book of Prayer - Eclipses": {
      "ar": "كتاب الكسوف",
      "fr": "Prière des Éclipses"
    },
    "The Book of Prayer - Funerals": {
      "ar": "كتاب الجنائز",
      "fr": "Prière des Funérailles"
    },
    "The Book of I'tikaf": {
      "ar": "كتاب الاعتكاف",
      "fr": "Le Livre de la Retraite Spirituelle (I'tikaf)"
    },
    "The Book of Suckling": {
      "ar": "كتاب الرضاع",
      "fr": "Le Livre de l'Allaitement"
    },
    "The Book of Invoking Curses": {
      "ar": "كتاب اللعان",
      "fr": "Le Livre du Li'an"
    },
    "The Book of Emancipating Slaves": {
      "ar": "كتاب العتق",
      "fr": "Le Livre de l'Affranchissement"
    },
    "The Book of Transactions": {
      "ar": "كتاب البيوع",
      "fr": "Le Livre des Transactions"
    },
    "The Book of Musaqah": {
      "ar": "كتاب المساقاة",
      "fr": "Le Livre de la Musaqah"
    },
    "The Book of the Rules of Inheritance": {
      "ar": "كتاب الفرائض",
      "fr": "Le Livre de l'Héritage"
    },
    "The Book of Gifts": {
      "ar": "كتاب الهبات",
      "fr": "Le Livre des Dons"
    },
    "The Book of Vows": {
      "ar": "كتاب النذر",
      "fr": "Le Livre des Vœux"
    },
    "The Book of Oaths": {
      "ar": "كتاب الأيمان",
      "fr": "Le Livre des Serments"
    },
    "The Book of Oaths, Muharibin, Qasas (Retaliation), and Diyat (Blood Money)": {
      "ar": "كتاب القسامة والمحاربين والقصاص والديات",
      "fr": "Serments, Talion et Prix du Sang"
    },
    "The Book of Legal Punishments": {
      "ar": "كتاب الحدود",
      "fr": "Le Livre des Peines Légales"
    },
    "The Book of Judicial Decisions": {
      "ar": "كتاب الأقضية",
      "fr": "Le Livre des Jugements"
    },
    "The Book of Lost Property": {
      "ar": "كتاب اللقطة",
      "fr": "Le Livre des Objets Trouvés"
    },
    "The Book of Jihad and Expeditions": {
      "ar": "كتاب الجهاد والسير",
      "fr": "Jihad et Expéditions"
    },
    "The Book on Government": {
      "ar": "كتاب الإمارة",
      "fr": "Le Livre du Gouvernement"
    },
    "The Book of Hunting, Slaughter, and what may be Eaten": {
      "ar": "كتاب الصيد والذبائح وما يؤكل من الحيوان",
      "fr": "Chasse et Abattage"
    },
    "The Book of Sacrifices": {
      "ar": "كتاب الأضاحي",
      "fr": "Le Livre des Sacrifices"
    },
    "The Book of Drinks": {
      "ar": "كتاب الأشربة",
      "fr": "Le Livre des Boissons"
    },
    "The Book of Clothes and Adornment": {
      "ar": "كتاب اللباس والزينة",
      "fr": "Vêtements et Parures"
    },
    "The Book of Manners and Etiquette": {
      "ar": "كتاب الأدب",
      "fr": "Manières et Étiquette"
    },
    "The Book of Greetings": {
      "ar": "كتاب السلام",
      "fr": "Le Livre des Salutations"
    },
    "The Book Concerning the Use of Correct Words": {
      "ar": "كتاب الألفاظ من الأدب وغيرها",
      "fr": "L'Usage des Mots Corrects"
    },
    "The Book of Poetry": {
      "ar": "كتاب الشعر",
      "fr": "Le Livre de la Poésie"
    },
    "The Book of Dreams": {
      "ar": "كتاب الرؤيا",
      "fr": "Le Livre des Rêves"
    },
    "The Book of Virtues": {
      "ar": "كتاب الفضائل",
      "fr": "Le Livre des Vertus"
    },
    "The Book of the Merits of the Companions": {
      "ar": "كتاب فضائل الصحابة",
      "fr": "Les Mérites des Compagnons"
    },
    "The Book of Virtue, Enjoining Good Manners, and Joining of the Ties of Kinship": {
      "ar": "كتاب البر والصلة والآداب",
      "fr": "Vertu et Liens de Parenté"
    },
    "The Book of Knowledge": {
      "ar": "كتاب العلم",
      "fr": "Le Livre du Savoir"
    },
    "The Book Pertaining to the Remembrance of Allah, Supplication, Repentance and Seeking Forgiveness": {
      "ar": "كتاب الذكر والدعاء والتوبة والاستغفار",
      "fr": "Souvenir, Invocation et Repentir"
    },
    "The Book of Heart-Melting Traditions": {
      "ar": "كتاب الرقاق",
      "fr": "Traditions qui Adoucissent le Cœur"
    },
    "The Book of Repentance": {
      "ar": "كتاب التوبة",
      "fr": "Le Livre du Repentir"
    },
    "Characteristics of The Hypocrites And Rulings Concerning Them": {
      "ar": "كتاب صفات المنافقين وأحكامهم",
      "fr": "Les Hypocrites"
    },
    "Characteristics of the Day of Judgment, Paradise, and Hell": {
      "ar": "كتاب صفة القيامة والجنة والنار",
      "fr": "Jugement, Paradis et Enfer"
    },
    "The Book of Paradise, its Description, its Bounties and its Inhabitants": {
      "ar": "كتاب الجنة وصفة نعيمها وأهلها",
      "fr": "Le Paradis et ses Délices"
    },
    "The Book of Tribulations and Portents of the Last Hour": {
      "ar": "كتاب الفتن وأشراط الساعة",
      "fr": "Tribulations et Signes de l'Heure"
    },
    "The Book of Zuhd and Softening of Hearts": {
      "ar": "كتاب الزهد والرقائق",
      "fr": "Ascétisme et Douceur des Cœurs"
    },
    "The Book of Commentary on the Qur'an": {
      "ar": "كتاب التفسير",
      "fr": "Commentaire du Coran"
    },

    // --- MAPPINGS FOR SUNAN ABU DAWUD ---
    "The Book Of The Prayer For Rain (Kitab al-Istisqa')": {
      "ar": "كتاب الاستسقاء",
      "fr": "Prière pour la Pluie"
    },
    "Prayer (Kitab Al-Salat): Detailed Rules of Law about the Prayer during Journey": {
      "ar": "كتاب صلاة السفر",
      "fr": "Prière du Voyageur"
    },
    "Prayer (Kitab Al-Salat): Voluntary Prayers": {
      "ar": "كتاب التطوع",
      "fr": "Prières Volontaires"
    },
    "Prayer (Kitab Al-Salat): Detailed Injunctions about Ramadan": {
      "ar": "كتاب شهر رمضان",
      "fr": "Mois de Ramadan"
    },
    "Prayer (Kitab Al-Salat): Prostration while reciting the Qur'an": {
      "ar": "كتاب سجود القرآن",
      "fr": "Prosternation du Coran"
    },
    "Prayer (Kitab Al-Salat): Detailed Injunctions about Witr": {
      "ar": "كتاب الوتر",
      "fr": "Prière du Witr"
    },
    "The Book of Lost and Found Items": {
      "ar": "كتاب اللقطة",
      "fr": "Objets Trouvés"
    },
    "The Office of the Judge (Kitab Al-Aqdiyah)": {
      "ar": "كتاب الأقضية",
      "fr": "La Magistrature"
    },
    "Knowledge (Kitab Al-Ilm)": {
      "ar": "كتاب العلم",
      "fr": "Le Savoir"
    },
    "Drinks (Kitab Al-Ashribah)": {
      "ar": "كتاب الأشربة",
      "fr": "Les Boissons"
    },
    "Foods (Kitab Al-At'imah)": {
      "ar": "كتاب الأطعمة",
      "fr": "Les Aliments"
    },
    "Medicine (Kitab Al-Tibb)": {
      "ar": "كتاب الطب",
      "fr": "La Médecine"
    },
    "Divination and Omens (Kitab Al-Kahanah Wa Al-Tatayyur)": {
      "ar": "كتاب الكهانة والتطير",
      "fr": "Divination et Présages"
    },
    "The Book of Manumission of Slaves": {
      "ar": "كتاب العتق",
      "fr": "L'Affranchissement"
    },
    "Dialects and Readings of the Qur'an (Kitab Al-Huruf Wa Al-Qira'at)": {
      "ar": "كتاب الحروف والقراءات",
      "fr": "Lectures du Coran"
    },
    "Hot Baths (Kitab Al-Hammam)": {
      "ar": "كتاب الحمام",
      "fr": "Les Bains"
    },
    "Sacrifice (Kitab Al-Dahaya)": {
      "ar": "كتاب الضحايا",
      "fr": "Les Sacrifices"
    },
    "Game (Kitab Al-Said)": {
      "ar": "كتاب الصيد",
      "fr": "Le Gibier"
    },
    "Wills (Kitab Al-Wasaya)": {
      "ar": "كتاب الوصايا",
      "fr": "Les Testaments"
    },
    "Shares of Inheritance (Kitab Al-Fara'id)": {
      "ar": "كتاب الفرائض",
      "fr": "Les Parts d'Héritage"
    },
    "Tribute, Spoils, and Rulership (Kitab Al-Kharaj, Wal-Fai' Wal-Imarah)": {
      "ar": "كتاب الخراج والفيء والإمارة",
      "fr": "Tribut, Butin et Gouvernance"
    },
    "Funerals (Kitab Al-Jana'iz)": {
      "ar": "كتاب الجنائز",
      "fr": "Les Funérailles"
    },
    "Oaths and Vows (Kitab Al-Aiman Wa Al-Nudhur)": {
      "ar": "كتاب الأيمان والنذور",
      "fr": "Serments et Vœux"
    },
    // "Commercial Transactions (Kitab Al-Buyu)": {
    //   "ar": "كتاب البيوع",
    //   "fr": "Transactions Commerciales"
    // },
    "Wages (Kitab Al-Ijarah)": {
      "ar": "كتاب الإجارة",
      "fr": "Les Salaires"
    },
    "Clothing (Kitab Al-Libas)": {
      "ar": "كتاب اللباس",
      "fr": "Les Vêtements"
    },
    "Combing the Hair (Kitab Al-Tarajjul)": {
      "ar": "كتاب الترجل",
      "fr": "Coiffure"
    },
    "Signet-Rings (Kitab Al-Khatam)": {
      "ar": "كتاب الخاتم",
      "fr": "Les Bagues"
    },
    "Trials and Fierce Battles (Kitab Al-Fitan Wa Al-Malahim)": {
      "ar": "كتاب الفتن والملاحم",
      "fr": "Épreuves et Batailles"
    },
    "The Promised Deliverer (Kitab Al-Mahdi)": {
      "ar": "كتاب المهدي",
      "fr": "Le Mahdi"
    },
    "Battles (Kitab Al-Malahim)": {
      "ar": "كتاب الملاحم",
      "fr": "Les Batailles"
    },
    "Prescribed Punishments (Kitab Al-Hudud)": {
      "ar": "كتاب الحدود",
      "fr": "Peines Prescrites"
    },
    "Types of Blood-Wit (Kitab Al-Diyat)": {
      "ar": "كتاب الديات",
      "fr": "Prix du Sang"
    },
    "Model Behavior of the Prophet (Kitab Al-Sunnah)": {
      "ar": "كتاب السنة",
      "fr": "La Sunna"
    },
    "General Behavior (Kitab Al-Adab)": {
      "ar": "كتاب الأدب",
      "fr": "Le Comportement"
    },

    // --- Jami' At-Tirmidhi ---
    "The Book on Purification": { "ar": "كتاب الطهارة", "fr": "Le Livre de la Purification" },
    "The Book on Salat (Prayer)": { "ar": "كتاب الصلاة", "fr": "Le Livre de la Prière" },
    "The Book on Al-Witr": { "ar": "كتاب الوتر", "fr": "Le Livre du Witr" },
    "The Book on the Day of Friday": { "ar": "كتاب الجمعة", "fr": "Le Livre du Vendredi" },
    "The Book on the Two Eids": { "ar": "كتاب العيدين", "fr": "Le Livre des Deux Aïds" },
    "The Book on Traveling": { "ar": "كتاب السفر", "fr": "Le Livre du Voyage" },
    "The Book on Zakat": { "ar": "كتاب الزكاة", "fr": "Le Livre de la Zakat" },
    "The Book on Fasting": { "ar": "كتاب الصوم", "fr": "Le Livre du Jeûne" },
    "The Book on Hajj": { "ar": "كتاب الحج", "fr": "Le Livre du Pèlerinage" },
    "The Book on Jana''iz (Funerals)": { "ar": "كتاب الجنائز", "fr": "Le Livre des Funérailles" },
    "The Book on Marriage": { "ar": "كتاب النكاح", "fr": "Le Livre du Mariage" },
    "The Book on Suckling": { "ar": "كتاب الرضاع", "fr": "Le Livre de l'Allaitement" },
    "The Book on Divorce and Li'an": { "ar": "كتاب الطلاق واللعان", "fr": "Le Livre du Divorce et du Li'an" },
    "The Book on Business": { "ar": "كتاب البيوع", "fr": "Le Livre des Ventes" },
    "The Chapters On Judgements From The Messenger of Allah": { "ar": "أبواب الأحكام", "fr": "Chapitres sur les Jugements" },
    "The Book on Blood Money": { "ar": "كتاب الديات", "fr": "Le Livre du Prix du Sang" },
    "The Book on Legal Punishments (Al-Hudud)": { "ar": "كتاب الحدود", "fr": "Le Livre des Peines Légales" },
    "The Book on Hunting": { "ar": "كتاب الصيد", "fr": "Le Livre de la Chasse" },
    "The Book on Sacrifices": { "ar": "كتاب الأضاحي", "fr": "Le Livre des Sacrifices" },
    "The Book on Vows and Oaths": { "ar": "كتاب النذور والأيمان", "fr": "Le Livre des Vœux et Serments" },
    "The Book on Military Expeditions": { "ar": "كتاب السير", "fr": "Le Livre des Expéditions" },
    "The Book on Virtues of Jihad": { "ar": "كتاب فضائل الجهاد", "fr": "Le Livre des Mérites du Jihad" },
    "The Book on Jihad": { "ar": "كتاب الجهاد", "fr": "Le Livre du Jihad" },
    "The Book on Clothing": { "ar": "كتاب اللباس", "fr": "Le Livre des Vêtements" },
    "The Book on Food": { "ar": "كتاب الأطعمة", "fr": "Le Livre de la Nourriture" },
    "The Book on Drinks": { "ar": "كتاب الأشربة", "fr": "Le Livre des Boissons" },
    "Chapters on Righteousness And Maintaining Good Relations With Relatives": { "ar": "أبواب البر والصلة", "fr": "Chapitres sur la Piété et les Liens de Parenté" },
    "Chapters on Medicine": { "ar": "أبواب الطب", "fr": "Chapitres sur la Médecine" },
    "Chapters On Inheritance": { "ar": "أبواب الفرائض", "fr": "Chapitres sur l'Héritage" },
    "Chapters On Wasaya (Wills and Testament)": { "ar": "أبواب الوصايا", "fr": "Chapitres sur les Testaments" },
    "Chapters On Wala' And Gifts": { "ar": "أبواب الولاء والهبة", "fr": "Chapitres sur l'Alliance et les Dons" },
    "Chapters On Al-Qadar": { "ar": "أبواب القدر", "fr": "Chapitres sur le Destin" },
    "Chapters On Al-Fitan": { "ar": "أبواب الفتن", "fr": "Chapitres sur les Troubles" },
    "Chapters On Dreams": { "ar": "أبواب الرؤيا", "fr": "Chapitres sur les Rêves" },
    "Chapters On Witnesses": { "ar": "أبواب الشهادات", "fr": "Chapitres sur les Témoignages" },
    "Chapters On Zuhd": { "ar": "أبواب الزهد", "fr": "Chapitres sur l'Ascétisme" },
    "Chapters on the description of the Day of Judgement, Ar-Riqaq, and Al-Wara'": { "ar": "أبواب صفة القيامة", "fr": "Description du Jugement Dernier" },
    "The Book on the Description of Hellfire": { "ar": "أبواب صفة جهنم", "fr": "Description de l'Enfer" },
    "The Book on Faith": { "ar": "أبواب الإيمان", "fr": "Le Livre de la Foi" },
    "Chapters on Knowledge": { "ar": "أبواب العلم", "fr": "Chapitres sur le Savoir" },
    "Chapters on Seeking Permission": { "ar": "أبواب الاستئذان", "fr": "Chapitres sur la Permission" },
    "Chapters on Manners": { "ar": "أبواب الأدب", "fr": "Chapitres sur les Bonnes Manières" },
    "Chapters on Parables": { "ar": "أبواب الأمثال", "fr": "Chapitres sur les Paraboles" },
    "Chapters on The Virtues of the Qur'an": { "ar": "أبواب فضائل القرآن", "fr": "Chapitres sur les Mérites du Coran" },
    "Chapters on Recitation": { "ar": "أبواب القراءات", "fr": "Chapitres sur la Récitation" },
    "Chapters on Tafsir": { "ar": "أبواب التفسير", "fr": "Chapitres sur l'Exégèse" },
    "Chapters on Supplication": { "ar": "أبواب الدعوات", "fr": "Chapitres sur les Invocations" },
    "Chapters on Virtues": { "ar": "أبواب المناقب", "fr": "Chapitres sur les Vertus" },

    // --- Sunan An-Nasai ---
    "The Book of Water": { "ar": "كتاب المياه", "fr": "Le Livre de l'Eau" },
    "The Book of Menstruation and Istihadah": { "ar": "كتاب الحيض والاستحاضة", "fr": "Menstrues et Istihadah" },
    "The Book of Ghusl and Tayammum": { "ar": "كتاب الغسل والتيمم", "fr": "Ghusl et Tayammum" },
    "The Book of Salah": { "ar": "كتاب الصلاة", "fr": "Le Livre de la Prière" },
    "The Book of the Times (of Prayer)": { "ar": "كتاب المواقيت", "fr": "Le Livre des Horaires" },
    "The Book of the Adhan (The Call to Prayer)": { "ar": "كتاب الأذان", "fr": "Le Livre de l'Adhan" },
    "The Book of the Masjids": { "ar": "كتاب المساجد", "fr": "Le Livre des Mosquées" },
    "The Book of the Qiblah": { "ar": "كتاب القبلة", "fr": "Le Livre de la Qibla" },
    "The Book of Leading the Prayer (Al-Imamah)": { "ar": "كتاب الإمامة", "fr": "Le Livre de l'Imamat" },
    "The Book of the Commencement of the Prayer": { "ar": "كتاب الافتتاح", "fr": "Commencement de la Prière" },
    "The Book of The At-Tatbiq (Clasping One's Hands Together)": { "ar": "كتاب التطبيق", "fr": "Le Livre du Tatbiq" },
    "The Book of Forgetfulness (In Prayer)": { "ar": "كتاب السهو", "fr": "Oubli dans la Prière" },
    "The Book of Jumu'ah (Friday Prayer)": { "ar": "كتاب الجمعة", "fr": "Le Livre du Vendredi" },
    "The Book of Shortening the Prayer When Traveling": { "ar": "كتاب تقصير الصلاة في السفر", "fr": "Raccourcissement de la Prière" },
    "The Book of Eclipses": { "ar": "كتاب الكسوف", "fr": "Le Livre des Éclipses" },
    "The Book of Praying for Rain (Al-Istisqa')": { "ar": "كتاب الاستسقاء", "fr": "Prière pour la Pluie" },
    "The Book of the Fear Prayer": { "ar": "كتاب صلاة الخوف", "fr": "Prière de la Peur" },
    "The Book of the Prayer for the Two 'Eids": { "ar": "كتاب صلاة العيدين", "fr": "Prière des Deux Fêtes" },
    "The Book of Qiyam Al-Lail (The Night Prayer) and Voluntary Prayers During the Day": { "ar": "كتاب قيام الليل وتطوع النهار", "fr": "Prière de Nuit et Surérogatoires" },
    "The Book of Funerals": { "ar": "كتاب الجنائز", "fr": "Le Livre des Funérailles" },
    "The Book of Zakah": { "ar": "كتاب الزكاة", "fr": "Le Livre de la Zakat" },
    "The Book of Horses, Races and Shooting": { "ar": "كتاب الخيل", "fr": "Chevaux et Tir" },
    "The Book of Endowments": { "ar": "كتاب الأحباس", "fr": "Le Livre des Dotations" },
    "The Book of Presents": { "ar": "كتاب النحل", "fr": "Le Livre des Cadeaux" },
    "The Book of ar-Ruqba": { "ar": "كتاب الرقبى", "fr": "Le Livre de la Ruqba" },
    "The Book of 'Umra": { "ar": "كتاب العمرى", "fr": "Le Livre de la Umra" },
    "The Book of Agriculture": { "ar": "كتاب المزارعة", "fr": "Le Livre de l'Agriculture" },
    "The Book of the Kind Treatment of Women": { "ar": "كتاب عشرة النساء", "fr": "Traitement des Femmes" },
    "The Book of Fighting [The Prohibition of Bloodshed]": { "ar": "كتاب تحريم الدم", "fr": "Interdiction du Sang" },
    "The Book of Distribution of Al-Fay'": { "ar": "كتاب قسم الفيء", "fr": "Distribution du Fay'" },
    "The Book of al-Bay'ah": { "ar": "كتاب البيعة", "fr": "Le Livre de l'Allégeance" },
    "The Book of al-'Aqiqah": { "ar": "كتاب العقيقة", "fr": "Le Livre de la Aqiqah" },
    "The Book of al-Fara' and al-'Atirah": { "ar": "كتاب الفرع والعتيرة", "fr": "Fara' et Atirah" },
    "The Book of Hunting and Slaughtering": { "ar": "كتاب الصيد والذبائح", "fr": "Chasse et Abattage" },
    "The Book of ad-Dahaya (Sacrifices)": { "ar": "كتاب الضحايا", "fr": "Le Livre des Sacrifices" },
    "The Book of Financial Transactions": { "ar": "كتاب البيوع", "fr": "Transactions Financières" },
    "The Book of Oaths (qasamah), Retaliation and Blood Money": { "ar": "كتاب القسامة", "fr": "Serments et Talion" },
    "The Book of Cutting off the Hand of the Thief": { "ar": "كتاب قطع السارق", "fr": "Couper la Main du Voleur" },
    "The Book Of Faith and its Signs": { "ar": "كتاب الإيمان وشرائعه", "fr": "Foi et ses Signes" },
    "The Book of Adornment": { "ar": "كتاب الزينة", "fr": "Le Livre de la Parure" },
    "The Book of the Etiquette of Judges": { "ar": "كتاب آداب القضاة", "fr": "Étiquette des Juges" },
    "The Book of Seeking Refuge with Allah": { "ar": "كتاب الاستعاذة", "fr": "Refuge auprès d'Allah" },

    // --- Sunan Ibn Majah ---
    "The Book of the Sunnah": { "ar": "المقدمة", "fr": "Le Livre de la Sunna" },
    "The Book of Purification and its Sunnah": { "ar": "كتاب الطهارة وسننها", "fr": "Purification et Sunna" },
    "The Book of the Prayer": { "ar": "كتاب الصلاة", "fr": "Le Livre de la Prière" },
    "The Book of the Adhan and the Sunnah Regarding It": { "ar": "كتاب الأذان والسنة فيها", "fr": "L'Adhan et sa Sunna" },
    "The Book On The Mosques And The Congregations": { "ar": "كتاب المساجد والجماعات", "fr": "Mosquées et Congrégations" },
    "Establishing the Prayer and the Sunnah Regarding Them": { "ar": "كتاب إقامة الصلاة والسنة فيها", "fr": "Établissement de la Prière" },
    "Chapters Regarding Funerals": { "ar": "كتاب الجنائز", "fr": "Chapitres sur les Funérailles" },
    "The Chapters Regarding Zakat": { "ar": "كتاب الزكاة", "fr": "Chapitres sur la Zakat" },
    "The Chapters on Marriage": { "ar": "كتاب النكاح", "fr": "Chapitres sur le Mariage" },
    "The Chapters on Divorce": { "ar": "كتاب الطلاق", "fr": "Chapitres sur le Divorce" },
    "The Chapters on Expiation": { "ar": "كتاب الكفارات", "fr": "Chapitres sur l'Expiation" },
    "The Chapters on Business Transactions": { "ar": "كتاب التجارات", "fr": "Chapitres sur le Commerce" },
    "The Chapters on Rulings": { "ar": "كتاب الأحكام", "fr": "Chapitres sur les Jugements" },
    "The Chapters on Gifts": { "ar": "كتاب الهبات", "fr": "Chapitres sur les Dons" },
    "The Chapters on Charity": { "ar": "كتاب الصدقات", "fr": "Chapitres sur la Charité" },
    "The Chapters on Pawning": { "ar": "كتاب الرهون", "fr": "Chapitres sur le Gage" },
    "The Chapters on Pre-emption": { "ar": "كتاب الشفعة", "fr": "Chapitres sur la Préemption" },
    "The Chapters on Lost Property": { "ar": "كتاب اللقطة", "fr": "Chapitres sur les Objets Trouvés" },
    "The Chapters on Manumission (of Slaves)": { "ar": "كتاب العتق", "fr": "Chapitres sur l'Affranchissement" },
    "The Chapters on Legal Punishments": { "ar": "كتاب الحدود", "fr": "Chapitres sur les Peines" },
    "The Chapters on Blood Money": { "ar": "كتاب الديات", "fr": "Chapitres sur le Prix du Sang" },
    "The Chapters on Wills": { "ar": "كتاب الوصايا", "fr": "Chapitres sur les Testaments" },
    "Chapters on Shares of Inheritance": { "ar": "كتاب الفرائض", "fr": "Chapitres sur l'Héritage" },
    "The Chapters on Jihad": { "ar": "كتاب الجهاد", "fr": "Chapitres sur le Jihad" },
    "Chapters on Hajj Rituals": { "ar": "كتاب المناسك", "fr": "Rites du Hajj" },
    "Chapters on Sacrifices": { "ar": "كتاب الأضاحي", "fr": "Chapitres sur les Sacrifices" },
    "Chapters on Slaughtering": { "ar": "كتاب الذبائح", "fr": "Chapitres sur l'Abattage" },
    "Chapters on Hunting": { "ar": "كتاب الصيد", "fr": "Chapitres sur la Chasse" },
    "Chapters on Food": { "ar": "كتاب الأطعمة", "fr": "Chapitres sur la Nourriture" },
    "Chapters on Drinks": { "ar": "كتاب الأشربة", "fr": "Chapitres sur les Boissons" },
    // "Chapters on Medicine": { "ar": "كتاب الطب", "fr": "Chapitres sur la Médecine" },
    "Chapters on Dress": { "ar": "كتاب اللباس", "fr": "Chapitres sur les Vêtements" },
    "Etiquette": { "ar": "كتاب الأدب", "fr": "Étiquette" },
    "Supplication": { "ar": "كتاب الدعاء", "fr": "Invocation" },

    // --- Muwatta Malik ---
    "The Times of Prayer": { "ar": "وقوت الصلاة", "fr": "Les Horaires de Prière" },
    "Purity": { "ar": "الطهارة", "fr": "La Pureté" },
    "Prayer": { "ar": "الصلاة", "fr": "La Prière" },
    "Forgetfulness in Prayer": { "ar": "السهو", "fr": "L'Oubli dans la Prière" },
    "Jumu'a": { "ar": "الجمعة", "fr": "Le Vendredi" },
    "Prayer in Ramadan": { "ar": "الصلاة في رمضان", "fr": "Prière pendant le Ramadan" },
    "Tahajjud": { "ar": "صلاة الليل", "fr": "Tahajjud" },
    "Prayer in Congregation": { "ar": "صلاة الجماعة", "fr": "Prière en Congrégation" },
    "Shortening the Prayer": { "ar": "قصر الصلاة", "fr": "Raccourcissement de la Prière" },
    "The Fear Prayer": { "ar": "صلاة الخوف", "fr": "Prière de la Peur" },
    "The Eclipse Prayer": { "ar": "صلاة الكسوف", "fr": "Prière de l'Éclipse" },
    "Asking for Rain": { "ar": "الاستسقاء", "fr": "Demande de Pluie" },
    "The Qibla": { "ar": "القبلة", "fr": "La Qibla" },
    "The Qur'an": { "ar": "القرآن", "fr": "Le Coran" },
    "Burials": { "ar": "الجنائز", "fr": "Enterrements" },
    "I'tikaf in Ramadan": { "ar": "الاعتكاف", "fr": "Retraite Spirituelle" },
    "Sacrificial Animals": { "ar": "الضحايا", "fr": "Animaux Sacrificiels" },
    "Slaughtering Animals": { "ar": "الذبائح", "fr": "Abattage" },
    "Game": { "ar": "الصيد", "fr": "Gibier" },
    "The 'Aqiqa": { "ar": "العقيقة", "fr": "La Aqiqah" },
    "Fara'id": { "ar": "الفرائض", "fr": "Héritages" },
    "Qirad": { "ar": "القراض", "fr": "Qirad" },
    "Sharecropping": { "ar": "المساقاة", "fr": "Métayage" },
    "Renting Land": { "ar": "كراء الأرض", "fr": "Location de Terres" },
    "Pre-emption in Property": { "ar": "الشفعة", "fr": "Préemption" },
    "Judgements": { "ar": "الأقضية", "fr": "Jugements" },
    "Setting Free and Wala'": { "ar": "العتق والولاء", "fr": "Affranchissement et Wala'" },
    "The Mukatab": { "ar": "المكاتب", "fr": "Le Mukatab" },
    "The Mudabbar": { "ar": "المدبر", "fr": "Le Mudabbar" },
    "Hudud": { "ar": "الحدود", "fr": "Hudud" },
    "The Oath of Qasama": { "ar": "القسامة", "fr": "Serment de Qasama" },
    "Madina": { "ar": "المدينة", "fr": "Médine" },
    "The Decree": { "ar": "القدر", "fr": "Le Décret" },
    "Good Character": { "ar": "حسن الخلق", "fr": "Bon Caractère" },
    "The Description of the Prophet, may Allah Bless Him and Grant Him Peace": { "ar": "صفة النبي صلى الله عليه وسلم", "fr": "Description du Prophète" },
    "The Evil Eye": { "ar": "العين", "fr": "Le Mauvais Œil" },
    "Hair": { "ar": "الشعر", "fr": "Cheveux" },
    "Visions": { "ar": "الرؤيا", "fr": "Visions" },
    "General Subjects": { "ar": "الجامع", "fr": "Sujets Généraux" },
    "The Oath of Allegiance": { "ar": "البيعة", "fr": "Serment d'Allégeance" },
    "Speech": { "ar": "الكلام", "fr": "La Parole" },
    "Jahannam": { "ar": "جهنم", "fr": "L'Enfer" },
    "Sadaqa": { "ar": "الصدقة", "fr": "Sadaqa" },
    "The Supplication of the Unjustly Wronged": { "ar": "دعوة المظلوم", "fr": "Invocation de l'Opprimé" },
    "Tribulations": { "ar": "كتاب الفتن", "fr": "Les Troubles" },
    "Zuhd": { "ar": "كتاب الزهد", "fr": "L'Ascétisme" },
    "The Book of Hajj": { "ar": "كتاب المناسك", "fr": "Le Livre du Pèlerinage" },
    "Chapters on the description of Paradise": { "ar": "أبواب صفة الجنة", "fr": "Description du Paradis" },
    "Forty Hadith of Shah Waliullah Dehlawi": { "ar": "أربعون حديث للشاه ولي الله الدهلوي", "fr": "Les Quarante Hadiths de Shah Waliullah Dehlawi" },
    "Forty Hadith of an-Nawawi": { "ar": "الأربعون النووية", "fr": "Les Quarante Hadiths de l'Imam Nawawi" },
    "Forty Hadith Qudsi": { "ar": "الأحاديث القدسية", "fr": "Les Quarante Hadiths Qudsi" },
    "The Names of the Prophet, may Allah Bless Him and Grant Him Peace": { "ar": "أسماء النبي صلى الله عليه وسلم", "fr": "Noms du Prophète" },
    
    // Muwatta Malik
    "The Two 'Ids": { "ar": "العيدين", "fr": "Les Deux Fêtes" },
    "Zakat": { "ar": "الزكاة", "fr": "Zakat" },
    "Hajj": { "ar": "الحج", "fr": "Hajj" },
    "Jihad": { "ar": "الجهاد", "fr": "Jihad" },
    "Vows and Oaths": { "ar": "النذور والأيمان", "fr": "Vœux et Serments" },
    "Marriage": { "ar": "النكاح", "fr": "Mariage" },
    "Suckling": { "ar": "الرضاع", "fr": "Allaitement" },
    "Business Transactions": { "ar": "البيوع", "fr": "Transactions Commerciales" },
    "Wills and Testaments": { "ar": "الوصايا", "fr": "Testaments" },
    "Blood-Money": { "ar": "الديات", "fr": "Le Prix du Sang" },
    "Greetings": { "ar": "الاستئذان", "fr": "Salutations" },
  };

  /// Translates a chapter title into the target locale.
  /// 
  /// [title]: The original English chapter title from the JSON metadata.
  /// [locale]: The current app locale (e.g. 'ar', 'fr', 'en').
  /// 
  /// Returns the translated string if available, otherwise returns [title].
  static String translate(String title, Locale locale) {
    if (locale.languageCode == 'en') {
      return title; // Already english
    }

    // Normalization to handle whitespace and inconsistencies
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return title;

    // Direct Lookup
    if (_dictionary.containsKey(trimmedTitle)) {
      final translations = _dictionary[trimmedTitle]!;
      if (translations.containsKey(locale.languageCode)) {
        return translations[locale.languageCode]!;
      }
    }
    
    // Case-insensitive fallback (expensive but useful for "introduction" vs "Introduction")
    try {
      final key = _dictionary.keys.firstWhere(
        (k) => k.toLowerCase() == trimmedTitle.toLowerCase(),
        orElse: () => '',
      );
      if (key.isNotEmpty) {
         final translations = _dictionary[key]!;
         if (translations.containsKey(locale.languageCode)) {
           return translations[locale.languageCode]!;
         }
      }
    } catch (_) {}

    return title;
  }
}
