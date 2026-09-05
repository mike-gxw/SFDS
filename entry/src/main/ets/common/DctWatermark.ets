// DctWatermark.ets - DCT 频域水印核心算法
// 8x8 分块 DCT，在中频系数上用「两系数大小关系」嵌入 1 bit，
// 嵌入到蓝色通道（人眼最不敏感）。
// 性能：一维 Float64Array + 复用 buffer（避免二维数组分配开销），
//       分批次 yield 让出主线程（避免 App Freeze）。

// 惰性初始化的 cos 表：cos[k*8+n] = cos((2n+1)kπ/16)
let gCos: Float64Array | null = null;

function getCos(): Float64Array {
  if (gCos === null) {
    const c: Float64Array = new Float64Array(64);
    for (let k: number = 0; k < 8; k++) {
      for (let n: number = 0; n < 8; n++) {
        c[k * 8 + n] = Math.cos((2 * n + 1) * k * Math.PI / 16);
      }
    }
    gCos = c;
  }
  return gCos;
}

function cVal(k: number): number {
  return k === 0 ? 0.7071067811865476 : 1.0;
}

// 让出主线程
function yieldToUI(): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      resolve();
    }, 0);
  });
}

// 8x8 DCT（一维行优先），block -> out，temp 为复用中间缓冲
function dct8x8(block: Float64Array, temp: Float64Array, out: Float64Array): void {
  const cos: Float64Array = getCos();
  for (let i: number = 0; i < 8; i++) {
    for (let k: number = 0; k < 8; k++) {
      let sum: number = 0;
      for (let n: number = 0; n < 8; n++) {
        sum += block[i * 8 + n] * cos[k * 8 + n];
      }
      temp[i * 8 + k] = cVal(k) * sum / 2;
    }
  }
  for (let j: number = 0; j < 8; j++) {
    for (let k: number = 0; k < 8; k++) {
      let sum: number = 0;
      for (let n: number = 0; n < 8; n++) {
        sum += temp[n * 8 + j] * cos[k * 8 + n];
      }
      out[k * 8 + j] = cVal(k) * sum / 2;
    }
  }
}

// 8x8 IDCT（一维行优先），block -> out
function idct8x8(block: Float64Array, temp: Float64Array, out: Float64Array): void {
  const cos: Float64Array = getCos();
  for (let j: number = 0; j < 8; j++) {
    for (let n: number = 0; n < 8; n++) {
      let sum: number = 0;
      for (let k: number = 0; k < 8; k++) {
        sum += cVal(k) * block[k * 8 + j] * cos[k * 8 + n];
      }
      temp[n * 8 + j] = sum;
    }
  }
  for (let i: number = 0; i < 8; i++) {
    for (let n: number = 0; n < 8; n++) {
      let sum: number = 0;
      for (let k: number = 0; k < 8; k++) {
        sum += cVal(k) * temp[i * 8 + k] * cos[k * 8 + n];
      }
      out[i * 8 + n] = sum / 4;
    }
  }
}

// 嵌入强度与中频系数位置
const EMBED_STRENGTH: number = 40;
const POS1: number = 3 * 8 + 2;
const POS2: number = 2 * 8 + 3;

// 每批处理块数后 yield 一次
const BATCH: number = 4000;

// 图片可承载的最大 bit 数（按 8x8 块计）
export function maxBitsCapacity(width: number, height: number): number {
  const cols: number = Math.floor(width / 8);
  const rows: number = Math.floor(height / 8);
  return cols * rows;
}

// 嵌入水印（异步分段，避免 App Freeze）
export async function embedWatermarkAsync(pixels: Uint8Array, width: number, height: number, bits: number[]): Promise<void> {
  const cols: number = Math.floor(width / 8);
  const rows: number = Math.floor(height / 8);
  const bitCount: number = bits.length;
  const block: Float64Array = new Float64Array(64);
  const temp: Float64Array = new Float64Array(64);
  const coeffs: Float64Array = new Float64Array(64);
  const spatial: Float64Array = new Float64Array(64);
  let processed: number = 0;
  for (let by: number = 0; by < rows; by++) {
    for (let bx: number = 0; bx < cols; bx++) {
      const blockIndex: number = by * cols + bx;
      if (blockIndex >= bitCount) {
        return;
      }
      for (let y: number = 0; y < 8; y++) {
        for (let x: number = 0; x < 8; x++) {
          const idx: number = ((by * 8 + y) * width + (bx * 8 + x)) * 4 + 2;
          block[y * 8 + x] = pixels[idx] - 128;
        }
      }
      dct8x8(block, temp, coeffs);
      const a: number = coeffs[POS1];
      const b: number = coeffs[POS2];
      const bit: number = bits[blockIndex];
      if (bit === 1) {
        if (a - b < EMBED_STRENGTH) {
          const mid: number = (a + b) / 2;
          coeffs[POS1] = mid + EMBED_STRENGTH / 2;
          coeffs[POS2] = mid - EMBED_STRENGTH / 2;
        }
      } else {
        if (b - a < EMBED_STRENGTH) {
          const mid: number = (a + b) / 2;
          coeffs[POS2] = mid + EMBED_STRENGTH / 2;
          coeffs[POS1] = mid - EMBED_STRENGTH / 2;
        }
      }
      idct8x8(coeffs, temp, spatial);
      for (let y: number = 0; y < 8; y++) {
        for (let x: number = 0; x < 8; x++) {
          const idx: number = ((by * 8 + y) * width + (bx * 8 + x)) * 4 + 2;
          let v: number = Math.round(spatial[y * 8 + x] + 128);
          if (v < 0) {
            v = 0;
          }
          if (v > 255) {
            v = 255;
          }
          pixels[idx] = v;
        }
      }
      processed++;
      if (processed % BATCH === 0) {
        await yieldToUI();
      }
    }
  }
}

// 提取前 blockCount 个块的位流（异步分段）
export async function extractWatermarkAsync(pixels: Uint8Array, width: number, height: number, blockCount: number): Promise<number[]> {
  const cols: number = Math.floor(width / 8);
  const rows: number = Math.floor(height / 8);
  const total: number = cols * rows;
  const limit: number = Math.min(blockCount, total);
  const bits: number[] = [];
  const block: Float64Array = new Float64Array(64);
  const temp: Float64Array = new Float64Array(64);
  const coeffs: Float64Array = new Float64Array(64);
  let processed: number = 0;
  for (let by: number = 0; by < rows; by++) {
    for (let bx: number = 0; bx < cols; bx++) {
      if (bits.length >= limit) {
        return bits;
      }
      for (let y: number = 0; y < 8; y++) {
        for (let x: number = 0; x < 8; x++) {
          const idx: number = ((by * 8 + y) * width + (bx * 8 + x)) * 4 + 2;
          block[y * 8 + x] = pixels[idx] - 128;
        }
      }
      dct8x8(block, temp, coeffs);
      bits.push(coeffs[POS1] > coeffs[POS2] ? 1 : 0);
      processed++;
      if (processed % BATCH === 0) {
        await yieldToUI();
      }
    }
  }
  return bits;
}
