const minInt64 = -9223372036854775808n;
const maxInt64 = 9223372036854775807n;
const reject = detail => { throw new Error(`${detail} No code was generated.`); };

// Original SQL text, never a JavaScript floating-point value, enters here.
export function numericLiteral(text) {
  if (/e/i.test(text)) reject('Scientific notation is not supported. Use ordinary decimal notation within the supported range or choose the Delphi parameter type manually.');
  if (/^-?\d+$/.test(text)) {
    const value = BigInt(text);
    if (value < minInt64 || value > maxInt64) reject('Integer literal is outside the signed Delphi Int64 range. Choose an appropriate decimal or unsigned Delphi type manually.');
    if (value === minInt64) return 'Low(Int64)';
    if (value === -2147483648n) return 'Low(Integer)';
    return value < -2147483648n || value > 2147483647n ? `Int64(${value})` : String(value);
  }
  const decimal = text.match(/^(-?)(\d*)\.(\d*)$/);
  if (!decimal || !(decimal[2] || decimal[3])) reject('Unsupported numeric literal.');
  const integral = decimal[2].replace(/^0+/, '') || '0';
  const fraction = decimal[3].replace(/0+$/, '');
  const digits = (integral + fraction).replace(/^0+/, '');
  // Standard floating-point output is approximate. Limit input precision rather
  // than silently rounding a high-precision decimal down to fit the default.
  if (digits.replace(/0+$/, '').length > 15) reject('Decimal literals with more than 15 significant digits require manual type selection, such as Currency or TBcd for exact decimal values.');
  if (digits) {
    const order = integral !== '0' ? integral.length - 1 : -(fraction.search(/[1-9]/) + 1);
    const rangeError = 'Decimal literal is outside the supported normal Double range (subnormal values are excluded). Choose the Delphi numeric type manually.';
    if (order < -308 || order > 308) reject(rangeError);
    // Compare decimal rationals against IEEE Double bounds using integers only.
    // This also bounds Win32 output when the compiler selects Extended.
    const numerator = BigInt(digits);
    const denominator = 10n ** BigInt(fraction.length);
    const maxDouble = ((1n << 53n) - 1n) << 971n;
    if (numerator > maxDouble * denominator || numerator * (1n << 1022n) < denominator) reject(rangeError);
  }
  // A decimal point keeps 1. and 1.000 in the floating-point family, not Integer.
  return `${decimal[1]}${integral}.${fraction || '0'}`;
}

export function pagingLiteral(text, max) {
  if (!/^\d+$/.test(text) || BigInt(text) > max) reject('Paging requires a non-negative integer literal within the Delphi parameter range.');
  const value = BigInt(text);
  return { value, code: value > 2147483647n ? `Int64(${value})` : String(value) };
}
