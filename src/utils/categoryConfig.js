export const CATEGORIES = {
  CHUGIM:   { label: 'חוגים',        color: '#4ECDC4', emoji: '🏊' },
  HOMEWORK: { label: 'שיעורי בית',   color: '#FFE66D', emoji: '📚' },
  FAMILY:   { label: 'משפחה',        color: '#FF6B6B', emoji: '👨‍👩‍👧' },
  FRIENDS:  { label: 'חברים',        color: '#A8E6CF', emoji: '👫' },
  OTHER:    { label: 'אחר',          color: '#B0BEC5', emoji: '📌' },
}

export const STATUSES = {
  ON_TIME:     { label: 'בזמן',        color: '#2ECC71', bg: '#E8F5E9' },
  MOVED:       { label: 'הוזז',        color: '#F39C12', bg: '#FFF8E1' },
  CANCELED:    { label: 'בוטל',        color: '#E74C3C', bg: '#FFEBEE' },
  RESCHEDULED: { label: 'נקבע מחדש',  color: '#3498DB', bg: '#E3F2FD' },
  POSTPONED:   { label: 'נדחה',        color: '#9B59B6', bg: '#F3E5F5' },
}

export const PRIORITIES = {
  URGENT: { label: 'דחוף',   color: '#FF3B30' },
  HIGH:   { label: 'גבוה',   color: '#FF9500' },
  MEDIUM: { label: 'בינוני', color: '#FFCC00' },
  LOW:    { label: 'נמוך',   color: '#34C759' },
}

export function getCategoryColor(cat) {
  return CATEGORIES[cat]?.color || CATEGORIES.OTHER.color
}

export function getCategoryLabel(cat) {
  return CATEGORIES[cat]?.label || cat
}

export function getStatusColor(status) {
  return STATUSES[status]?.color || '#9E9E9E'
}

export function getStatusLabel(status) {
  return STATUSES[status]?.label || status
}

export function getStatusBg(status) {
  return STATUSES[status]?.bg || '#F5F5F5'
}

export function isDark(hex) {
  const r = parseInt(hex.slice(1,3),16)
  const g = parseInt(hex.slice(3,5),16)
  const b = parseInt(hex.slice(5,7),16)
  return (0.299*r + 0.587*g + 0.114*b) / 255 < 0.5
}
