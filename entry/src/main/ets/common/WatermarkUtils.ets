// WatermarkUtils.ets - 文本 <-> 位流 编码解码工具
// 编码格式：[16-bit 长度 N][N 个字符，每字符 16-bit UTF-16]

// 文本转位流
export function textToBits(text: string): number[] {
  const bits: number[] = [];
  const len: number = text.length;
  for (let i: number = 15; i >= 0; i--) {
    bits.push((len >> i) & 1);
  }
  for (let i: number = 0; i < len; i++) {
    const code: number = text.charCodeAt(i);
    for (let j: number = 15; j >= 0; j--) {
      bits.push((code >> j) & 1);
    }
  }
  return bits;
}

// 位流转文本（带越界保护）
export function bitsToText(bits: number[]): string {
  if (bits.length < 16) {
    return '';
  }
  let len: number = 0;
  for (let i: number = 0; i < 16; i++) {
    len = (len << 1) | (bits[i] & 1);
  }
  const maxChars: number = Math.floor((bits.length - 16) / 16);
  const n: number = Math.min(len, maxChars);
  let result: string = '';
  let idx: number = 16;
  for (let i: number = 0; i < n; i++) {
    let code: number = 0;
    for (let j: number = 0; j < 16; j++) {
      code = (code << 1) | (bits[idx] & 1);
      idx++;
    }
    result += String.fromCharCode(code);
  }
  return result;
}
