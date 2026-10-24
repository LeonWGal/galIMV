"""Regenerate galIMV's QML catalog and optionally sync the mini copy."""
import argparse,json
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mini-root',type=Path,help='Path to the galIMVmini source directory')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    catalog=root/'resources/ui/design.json'
    design=json.loads(catalog.read_text(encoding='utf-8'))
    module=root/'qml/DesignSystem.js'
    source=module.read_text(encoding='utf-8')
    start=source.index('var design = ')+len('var design = ')
    end=source.index(';\nfunction rgb',start)
    module.write_text(source[:start]+json.dumps(design,ensure_ascii=False,indent=2)+source[end:],encoding='utf-8',newline='\n')
    if args.mini_root is not None:
        mini=args.mini_root.resolve()
        if not (mini/'main.py').is_file() or not (mini/'core').is_dir():
            parser.error('--mini-root must point to the galIMVmini source directory')
        target=mini/'resources/ui/design.json';target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(catalog.read_bytes())
    print(f'Synchronized {len(design["icons"])} SVG icons and shared design tokens.')

if __name__=='__main__':main()
