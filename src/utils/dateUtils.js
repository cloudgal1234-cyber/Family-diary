const HE_DAYS   = ['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת']
const HE_MONTHS = ['ינואר','פברואר','מרץ','אפריל','מאי','יוני','יולי','אוגוסט','ספטמבר','אוקטובר','נובמבר','דצמבר']

export function tsToDateStr(ts) {
  const d = new Date(ts)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}

export function dateStrToTs(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number)
  return new Date(y, m - 1, d).getTime()
}

export function getMidnight(ts) {
  const d = new Date(ts)
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
}

export function formatTime(ts) {
  const d = new Date(ts)
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}

export function formatTimeRange(startTs, endTs) {
  return `${formatTime(startTs)} – ${formatTime(endTs)}`
}

export function formatDateHebrew(ts) {
  const d = new Date(ts)
  return `יום ${HE_DAYS[d.getDay()]}, ${d.getDate()} ב${HE_MONTHS[d.getMonth()]}`
}

export function formatDateShort(ts) {
  const d = new Date(ts)
  return `${d.getDate()}/${d.getMonth()+1}`
}

export function getDayName(ts) {
  return HE_DAYS[new Date(ts).getDay()]
}

export function getWeekDays(weekStartTs) {
  return Array.from({ length: 7 }, (_, i) => {
    const ts = weekStartTs + i * 86400000
    return { ts, dateStr: tsToDateStr(ts), dayName: getDayName(ts) }
  })
}

export function getCurrentWeekStart() {
  const now = new Date()
  const day = now.getDay()                         // 0=Sun
  const sunday = new Date(now)
  sunday.setDate(now.getDate() - day)
  sunday.setHours(0, 0, 0, 0)
  return sunday.getTime()
}

export function tsToMinutesFromMidnight(ts) {
  const midnight = getMidnight(ts)
  return Math.round((ts - midnight) / 60000)
}

export function isToday(ts) {
  return tsToDateStr(ts) === tsToDateStr(Date.now())
}

export function isSameDay(ts1, ts2) {
  return tsToDateStr(ts1) === tsToDateStr(ts2)
}

export function timeUntil(ts) {
  const diff = ts - Date.now()
  if (diff < 0)         return 'כבר התחיל'
  const mins  = Math.round(diff / 60000)
  if (mins < 60)        return `בעוד ${mins} דק׳`
  const hours = Math.round(mins / 60)
  if (hours < 24)       return `בעוד ${hours} שע׳`
  return `בעוד ${Math.round(hours / 24)} ימים`
}

export function combineDateAndTime(dateStr, timeStr) {
  const [y, m, d] = dateStr.split('-').map(Number)
  const [h, min]  = timeStr.split(':').map(Number)
  return new Date(y, m - 1, d, h, min).getTime()
}

export function todayStr() {
  return tsToDateStr(Date.now())
}

export function tomorrowStr() {
  return tsToDateStr(Date.now() + 86400000)
}
