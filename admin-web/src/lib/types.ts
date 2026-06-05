export type NewsRow = {
  id: string;
  title: string;
  description: string;
  type: "text" | "image" | "youtube";
  media_url: string;
  source_url: string;
  publish_date: string; // ISO
  valid_until: string; // ISO
  language: string;
  category_ar: string | null;
  category_en: string | null;
  category_fr: string | null;
  target_languages: string[];
  target_countries: string[];
  excluded_countries: string[];
  is_featured: boolean;
  send_notification: boolean;
  is_published: boolean;
  updated_by: string | null;
  created_at?: string;
  updated_at?: string;
};

export type ReciterRow = {
  code: string;
  name_ar: string;
  name_latin: string;
  ayahs_path: string;
  surahs_path: string | null;
  sort_order: number;
  is_enabled: boolean;
  updated_by: string | null;
  created_at?: string;
  updated_at?: string;
};
