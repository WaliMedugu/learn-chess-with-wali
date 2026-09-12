import os
import struct
import subprocess

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_png = os.path.join(base_dir, "121-learn-chess-with-sol.png")
    input_jpg = os.path.join(base_dir, "121-learn-chess-with-sol.jpg")
    input_mp4 = os.path.join(base_dir, "121-learn-chess-with-sol.mp4")
    
    output_dir = os.path.join(base_dir, "motionphoto")
    os.makedirs(output_dir, exist_ok=True)
    
    output_motion_jpg = os.path.join(output_dir, "121-learn-chess-with-sol.motion.jpg")
    output_samsung_jpg = os.path.join(output_dir, "MVIMG_20260810_195826.jpg")
    output_samsung_orig_name = os.path.join(output_dir, "20260810_195826.jpg")

    ffmpeg_path = r"C:\Users\Wali\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Shared_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build-shared\bin\ffmpeg.exe"

    print("Converting PNG to JPEG using FFmpeg...")
    subprocess.run([ffmpeg_path, "-y", "-i", input_png, "-q:v", "2", input_jpg], check=True)

    with open(input_jpg, "rb") as f:
        jpg_bytes = f.read()

    with open(input_mp4, "rb") as f:
        mp4_bytes = f.read()

    video_size = len(mp4_bytes)
    print(f"Base JPEG size: {len(jpg_bytes)} bytes")
    print(f"Video size: {video_size} bytes")

    # Samsung exact XMP XML packet from Immamotion.jpg
    xmp_xml = f"""http://ns.adobe.com/xap/1.0/\x00<?xpacket begin="?" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core Test.SNAPSHOT">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
        xmlns:Container="http://ns.google.com/photos/1.0/container/"
        xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
        xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
      GCamera:MotionPhoto="1"
      GCamera:MotionPhotoVersion="1"
      GCamera:MotionPhotoPresentationTimestampUs="0">
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Semantic="Primary"
              Item:Mime="image/jpeg"
              Item:Padding="0"/>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="video/mp4"
              Item:Semantic="MotionPhoto"
              Item:Length="{video_size}"
              Item:Padding="0"/>
          </rdf:li>
        </rdf:Seq>
      </Container:Directory>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
"""
    payload = xmp_xml.encode('utf-8')
    length = len(payload) + 2
    app1_marker = b"\xFF\xE1" + struct.pack(">H", length) + payload

    # Samsung exact marker inserted between JPEG and MP4
    samsung_mid_marker = b"\x00a\x0c\x18\x00\x00\x00Camera_Capture_Mode_Info1\x00\x003\x0a\x14\x00\x00\x00MotionPhoto_AutoPlay"

    # Samsung exact SEFT trailer attached at the end
    samsung_seft_trailer = b"SEFHk\x00\x00\x00\x08\x00\x00\x00\x00\x00\x01\n\x8c\x0c:\x00#\x00\x00\x00\x00\x00\xa1\ni\x0c:\x00\x13\x00\x00\x00\x00\x00!\rV\x0c:\x00\x1e\x00\x00\x00\x00\x00\xc1\x0c8\x0c:\x00\x1b\x00\x00\x00\x00\x00\xd2\x0c\x1d\x0c:\x00\x17\x00\x00\x00\x00\x00a\x0c\x06\x0c:\x00!\x00\x00\x00\x00\x003\n\xe5\x0b:\x00\x95\xb4\x07\x00\x00\x000\nPW2\x00PW2\x00l\x00\x00\x00SEFT"

    if not jpg_bytes.startswith(b"\xFF\xD8"):
        raise ValueError("JPEG does not start with SOI")

    # Build final combined binary data
    # 1. SOI + APP1 XMP + Rest of JPEG
    # 2. Samsung MotionPhoto_AutoPlay marker
    # 3. MP4 video bytes
    # 4. Samsung SEFT trailer
    final_data = jpg_bytes[:2] + app1_marker + jpg_bytes[2:] + samsung_mid_marker + mp4_bytes + samsung_seft_trailer

    for out_path in [output_motion_jpg, output_samsung_jpg, output_samsung_orig_name]:
        with open(out_path, "wb") as f:
            f.write(final_data)
        print(f"Generated Samsung Motion Photo at: {out_path} ({len(final_data)} bytes)")

if __name__ == "__main__":
    main()
