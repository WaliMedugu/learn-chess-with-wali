const puppeteer = require('c:/social media/node_modules/puppeteer-core');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

(async () => {
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const ffmpegPath = 'C:\\Users\\Wali\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg.Shared_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1-full_build-shared\\bin\\ffmpeg.exe';
  const htmlPath = path.resolve(__dirname, '121-learn-chess-with-sol.html');
  const tempDir = path.resolve(__dirname, 'temp_frames');
  const outputPng = path.resolve(__dirname, '121-learn-chess-with-sol.png');
  const outputMp4 = path.resolve(__dirname, '121-learn-chess-with-sol.mp4');
  const outputGif = path.resolve(__dirname, '121-learn-chess-with-sol.gif');

  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }

  console.log('Launching Google Chrome...');
  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  console.log('Loading HTML file and waiting for assets to load...');
  await page.goto(`file:///${htmlPath.replace(/\\/g, '/')}`, {
    waitUntil: 'networkidle0'
  });

  // Step 1: Capture High-Res PNG (deviceScaleFactor: 2 -> 2160x2700)
  console.log('Capturing High-Res PNG (deviceScaleFactor: 2)...');
  await page.setViewport({ width: 1080, height: 1350, deviceScaleFactor: 2 });
  await page.screenshot({ path: outputPng, type: 'png' });
  console.log(`Saved High-Res PNG to: ${outputPng}`);

  // Step 2: Capture Frames for Animation (deviceScaleFactor: 1.5 -> 1620x2025)
  console.log('Capturing animation frames (deviceScaleFactor: 1.5)...');
  await page.setViewport({ width: 1080, height: 1350, deviceScaleFactor: 1.5 });

  const totalFrames = 75; // 3 seconds at 25fps
  for (let i = 0; i < totalFrames; i++) {
    const frameNumber = String(i).padStart(3, '0');
    const framePath = path.join(tempDir, `frame_${frameNumber}.png`);
    await page.screenshot({ path: framePath, type: 'png' });
    
    if (i % 10 === 0) {
      console.log(`Captured frame ${i + 1}/${totalFrames}...`);
    }
  }

  await browser.close();
  console.log('Chrome closed. Compiling media formats using FFmpeg...');

  try {
    // Step 3: Compile MP4 video (H.264, YUV420p)
    console.log('Compiling MP4 video...');
    const mp4Cmd = `"${ffmpegPath}" -y -framerate 25 -i "${path.join(tempDir, 'frame_%03d.png')}" -c:v libx264 -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "${outputMp4}"`;
    execSync(mp4Cmd, { stdio: 'inherit' });
    console.log(`Saved MP4 to: ${outputMp4}`);

    // Step 4: Compile high-quality animated GIF (using advanced dithering)
    console.log('Compiling animated GIF...');
    const gifCmd = `"${ffmpegPath}" -y -framerate 25 -i "${path.join(tempDir, 'frame_%03d.png')}" -vf "split[s0][s1];[s0]palettegen=stats_mode=full[p];[s1][p]paletteuse=dither=sierra2_4a" "${outputGif}"`;
    execSync(gifCmd, { stdio: 'inherit' });
    console.log(`Saved GIF to: ${outputGif}`);

  } catch (error) {
    console.error('FFmpeg compilation failed:', error.message);
  } finally {
    // Step 5: Clean up temp_frames
    console.log('Cleaning up temporary frame files...');
    const files = fs.readdirSync(tempDir);
    for (const file of files) {
      fs.unlinkSync(path.join(tempDir, file));
    }
    fs.rmdirSync(tempDir);
    console.log('Cleanup completed.');
  }

  console.log('All formats generated successfully!');
})();
