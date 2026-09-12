import os
import struct
import subprocess

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_png = os.path.join(base_dir, "121-learn-chess-with-sol.png")
    input_jpg = os.path.join(base_dir, "121-learn-chess-with-sol.jpg")
    input_mp4 = os.path.join(base_dir, "121-learn-chess-with-sol.mp4")
    
    # We will generate both standard name and Samsung camera style naming pattern
    output_motion_jpg = os.path.join(base_dir, "121-learn-chess-with-sol.motion.jpg")
    output_samsung_jpg = os.path.join(base_dir, "MVIMG_20260810_195826.jpg")

    ffmpeg_path = r"C:\Users\Wali\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Shared_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build-shared\bin\ffmpeg.exe"

    print("Converting PNG to JPEG using FFmpeg...")
    subprocess.run([ffmpeg_path, "-y", "-i", input_png, "-q:v", "2", input_jpg], check=True)
    print(f"Saved JPEG still image to: {input_jpg}")

    # Read base JPEG and MP4 files
    with open(input_jpg, "rb") as f:
        jpg_bytes = f.read()

    with open(input_mp4, "rb") as f:
        mp4_bytes = f.read()

    jpg_size = len(jpg_bytes)
    video_size = len(mp4_bytes)
    print(f"Original JPEG size: {jpg_size} bytes")
    print(f"Video size: {video_size} bytes")

    # Fixed-point iteration to compute the exact final JPEG size (including APP1 header)
    final_jpg_size = jpg_size + 1500  # initial guess
    xmp_xml = ""
    app1_marker = b""
    
    for i in range(5):
        xmp_xml = f"""<?xpacket begin="?" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
        xmlns:Camera="http://ns.google.com/photos/1.0/camera/"
        xmlns:Container="http://ns.google.com/photos/1.0/container/">
      <Camera:MotionPhoto>1</Camera:MotionPhoto>
      <Camera:MotionPhotoVersion>1</Camera:MotionPhotoVersion>
      <Camera:MotionPhotoPresentationTimestampUs>0</Camera:MotionPhotoPresentationTimestampUs>
      <Camera:MicroVideo>1</Camera:MicroVideo>
      <Camera:MicroVideoVersion>1</Camera:MicroVideoVersion>
      <Camera:MicroVideoOffset>{video_size}</Camera:MicroVideoOffset>
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item>
              <Container:Mime>image/jpeg</Container:Mime>
              <Container:Semantic>Primary</Container:Semantic>
              <Container:Length>{final_jpg_size}</Container:Length>
            </Container:Item>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item>
              <Container:Mime>video/mp4</Container:Mime>
              <Container:Semantic>MotionPhoto</Container:Semantic>
              <Container:Length>{video_size}</Container:Length>
            </Container:Item>
          </rdf:li>
        </rdf:Seq>
      </Container:Directory>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>"""

        namespace_signature = b"http://ns.adobe.com/xap/1.0/\x00"
        payload = namespace_signature + xmp_xml.encode('utf-8')
        length = len(payload) + 2
        app1_marker = b"\xFF\xE1" + struct.pack(">H", length) + payload
        
        # Calculate new final JPEG size
        final_jpg_size = jpg_size + len(app1_marker)

    print(f"Calculated final JPEG size: {final_jpg_size} bytes")

    # Verify JPEG starts with SOI (0xFFD8)
    if not jpg_bytes.startswith(b"\xFF\xD8"):
        raise ValueError("Input JPEG does not start with SOI marker (0xFFD8)")

    # Inject APP1 marker immediately after SOI (0xFFD8)
    combined_bytes = jpg_bytes[:2] + app1_marker + jpg_bytes[2:] + mp4_bytes

    # Save to both standard name and Samsung style name
    for path_name in [output_motion_jpg, output_samsung_jpg]:
        with open(path_name, "wb") as f:
            f.write(combined_bytes)
        print(f"Motion Photo generated successfully at: {path_name}")

if __name__ == "__main__":
    main()
