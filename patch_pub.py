import os
import glob

pub_cache = os.path.expanduser('~/.pub-cache')
if not os.path.exists(pub_cache):
    pub_cache = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Pub', 'Cache')

if not os.path.exists(pub_cache):
    flutter_cache = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'flutter', '.pub-cache')
    if os.path.exists(flutter_cache):
        pub_cache = flutter_cache

hosted = os.path.join(pub_cache, 'hosted', 'pub.dev')
if os.path.exists(hosted):
    for d in os.listdir(hosted):
        if d.startswith('speech_to_text_web-'):
            file_path = os.path.join(hosted, d, 'lib', 'speech_to_text_web.dart')
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content.replace(
                    'var error = _convertJsError(event);',
                    'var error = "error";\n        try { error = _convertJsError(event); } catch(e) {}'
                )
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print('Patched', file_path)
