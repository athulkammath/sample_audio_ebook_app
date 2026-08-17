import zipfile
import os

# Create project assets directories
os.makedirs('assets/ebooks', exist_ok=True)
os.makedirs('assets/audio', exist_ok=True)

# Generate a minimal valid EPUB structure
def generate_epub(filename):
    with zipfile.ZipFile(filename, 'w') as epub:
        # 1. mimetype
        epub.writestr('mimetype', 'application/epub+zip', compress_type=zipfile.ZIP_STORED)
        
        # 2. container.xml
        container_xml = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
    </rootfiles>
</container>"""
        epub.writestr('META-INF/container.xml', container_xml)
        
        # 3. content.opf
        content_opf = """<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="pub-id">urn:uuid:12345</dc:identifier>
        <dc:title>Sample E-Book</dc:title>
        <dc:language>en</dc:language>
    </metadata>
    <manifest>
        <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
        <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    </manifest>
    <spine toc="toc">
        <itemref idref="chapter1"/>
    </spine>
</package>"""
        epub.writestr('OEBPS/content.opf', content_opf)

        # 4. chapter1.xhtml
        chapter1_xhtml = """<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body>
    <h1>Chapter 1: The Beginning</h1>
    <p>This is a sample EPUB file for testing the E-Book reader.</p>
    <p>You can tap any word to hear it spoken using TTS.</p>
    <p>Long press a word to highlight it in yellow.</p>
    <p>This POC demonstrates real EPUB parsing with epubx and flutter_html.</p>
</body>
</html>"""
        epub.writestr('OEBPS/chapter1.xhtml', chapter1_xhtml)

        # 5. toc.ncx
        toc_ncx = """<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
    <head><meta name="dtb:uid" content="urn:uuid:12345"/></head>
    <docTitle><text>Sample E-Book</text></docTitle>
    <navMap>
        <navPoint id="navPoint-1" playOrder="1">
            <navLabel><text>Chapter 1</text></navLabel>
            <content src="chapter1.xhtml"/>
        </navPoint>
    </navMap>
</ncx>"""
        epub.writestr('OEBPS/toc.ncx', toc_ncx)

# Generate a dummy MP3 (just an empty file might work for POC metadata, but won't play)
def generate_mp3(filename):
    # We'll create a 0-byte file. In a real app, you'd have actual audio.
    # just_audio might error, but the UI logic will be visible.
    with open(filename, 'wb') as f:
        f.write(b'\0' * 1024)

generate_epub('assets/ebooks/sample.epub')
generate_mp3('assets/audio/sample.mp3')
print("Sample assets generated successfully.")
