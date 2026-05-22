export interface User {
  id: string;
  phone_number: string;
  email?: string;
  role: 'ADMIN' | 'ARTISAN' | 'CLIENT';
  verification_status: 'PENDING' | 'VERIFIED' | 'CERTIFIED';
  is_active: boolean;
  is_phone_verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  user: User;
}

export interface DashboardStats {
  totalClients: number;
  totalArtisans: number;
  activeSubscriptions: number;
  totalRevenueFcfa: number;
  pendingVerifications: number;
  totalReviews: number;
  pendingManualPayments?: number;
  monthlyManualRevenueFcfa?: number;
  manualValidationRate?: number;
}

export interface VerificationDocumentPage {
  id: string;
  document_id: string;
  file_url: string;
  object_key?: string;
  page_role: 'FRONT' | 'BACK' | 'MAIN' | 'EXTRA';
  page_order: number;
  created_at: string;
}

export interface VerificationDocument {
  id: string;
  user_id: string;
  document_type: string;
  file_url: string;
  object_key?: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejection_reason?: string;
  reviewed_by?: string;
  submitted_at: string;
  updated_at: string;
  user?: User;
  pages?: VerificationDocumentPage[];
}

export interface ArtisanProfile {
  id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  business_name: string;
  city: string;
  commune: string;
  whatsapp_number: string;
  bio?: string;
  rating_avg: number;
  total_reviews: number;
  is_available: boolean;
  created_at: string;
  user?: User;
  category?: { id: string; name: string };
  subcategory?: { id: string; name: string };
  subscription?: {
    id: string;
    status: 'ACTIVE' | 'EXPIRED' | 'CANCELLED' | 'PENDING';
    expires_at: string;
  };
}

export interface AnalyticsData {
  period: string;
  totalSearches: number;
  totalProfileViews: number;
  totalContacts: number;
  recentLogins: number;
}

export interface ClientProfile {
  id: string;
  first_name: string;
  last_name: string;
  city: string;
  commune: string;
  created_at: string;
  user: {
    id: string;
    phone_number: string;
    is_active: boolean;
    is_phone_verified: boolean;
    verification_status: string;
  };
}

export interface SubscriptionRecord {
  id: string;
  artisan_profile_id: string;
  plan: string;
  amount_fcfa: number;
  status: 'ACTIVE' | 'EXPIRED' | 'CANCELLED' | 'PENDING';
  starts_at: string;
  expires_at: string;
  auto_renew: boolean;
  created_at: string;
  artisan_profile: {
    id: string;
    first_name: string;
    last_name: string;
    business_name: string;
    user: {
      phone_number: string;
    };
  };
  payments: {
    id: string;
    amount_fcfa: number;
    status: 'PENDING' | 'SUCCESS' | 'FAILED';
    paid_at: string;
  }[];
}

export interface ReviewRecord {
  id: string;
  rating: number;
  comment: string;
  artisan_reply?: string | null;
  artisan_reply_at?: string | null;
  created_at: string;
  client: {
    id: string;
    first_name: string;
    last_name: string;
  };
  artisan: {
    id: string;
    first_name: string;
    last_name: string;
    business_name: string;
  };
}

export interface ActivityLog {
  _id: string;
  actorId: string;
  action:
    | 'SEARCH'
    | 'PROFILE_VIEW'
    | 'CONTACT_CLICK'
    | 'LOGIN'
    | 'PAYMENT_ATTEMPT'
    | 'REGISTRATION'
    | 'SUBSCRIPTION_UPDATED'
    | 'PAYMENT_MANUAL_INITIATED'
    | 'PROOF_SUBMITTED'
    | 'PROOF_VALIDATED'
    | 'PAYMENT_MANUAL_REJECTED'
    | 'PAYMENT_MANUAL_REOPENED'
    | 'PAYMENT_MANUAL_EXPIRED'
    | 'PAYMENT_MANUAL_SOFT_DELETED'
    | 'REFUND_PROCESSED';
  targetId?: string;
  metadata?: Record<string, unknown>;
  timestamp: string;
}

export interface PaymentProofRecord {
  id: string;
  payment_manual_id: string;
  image_url: string;
  image_hash_sha256: string;
  submitted_at: string;
  declared_payment_time?: string | null;
  upload_attempt_number: number;
  file_type?: string | null;
  file_size_kb?: number | null;
  file_resolution?: string | null;
  has_exif: boolean;
  exif_capture_date?: string | null;
  exif_modified_date?: string | null;
  exif_device?: string | null;
  exif_software?: string | null;
  ai_suspicion_score: number;
  is_suspected_fraud: boolean;
  deletion_requested: boolean;
}

export interface PaymentManualRecord {
  id: string;
  transaction_id: string;
  amount_fcfa: number;
  provider: 'WAVE' | 'ORANGE_MONEY' | 'MTN_MOMO' | 'MOOV_MONEY';
  status: 'PENDING' | 'PENDING_ADMIN' | 'COMPLETED' | 'REJECTED' | 'EXPIRED';
  sender_number?: string | null;
  created_at: string;
  updated_at: string;
  expires_at_admin?: string | null;
  validated_at?: string | null;
  rejected_at?: string | null;
  rejection_reason?: string | null;
  request_number: number;
  refund_required: boolean;
  refund_done_at?: string | null;
  cooldown_until?: string | null;
  cooldown_cycle?: number;
  attempted_refund_count: number;
  timeline?: Array<Record<string, unknown>>;
  subscription?: {
    id: string;
    artisan_profile?: {
      id: string;
      first_name?: string;
      last_name?: string;
      business_name?: string | null;
      user?: {
        id: string;
        phone_number?: string;
      };
    };
  };
  proofs?: PaymentProofRecord[];
}
