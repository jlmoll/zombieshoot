"""Normalize GDScript declaration/callback order, tabs and 100-column layout."""

import argparse
from collections import Counter
from pathlib import Path
import re

from gdtoolkit.formatter import check_formatting_safety, format_code
from gdtoolkit.common.ast import AbstractSyntaxTree
from gdtoolkit.parser import parser

ROOT = Path(__file__).resolve().parent.parent
CALLBACKS = [
    "_static_init", "_init", "_initialize", "_enter_tree", "_ready", "_exit_tree",
    "_process", "_physics_process", "_input", "_shortcut_input",
    "_unhandled_key_input", "_unhandled_input", "_notification", "_finalize",
]
FUNCTION = re.compile(r"^(?:static )?func (\w+)\(", re.MULTILINE)


def order_declarations(source: str) -> str:
    """Stable-sort declarations; preserve initializer order inside each section."""
    lines = source.splitlines(keepends=True)
    tree = parser.parse(source, gather_metadata=True)
    intervals = []
    annotation_start = None
    for node in tree.children:
        if node.data in {"const_stmt", "class_var_stmt", "static_class_var_stmt"}:
            start = node.meta.line - 1 if annotation_start is None else annotation_start
            intervals.append((start, node.meta.end_line))
            annotation_start = None
        elif node.data == "property_body_def" and intervals:
            intervals[-1] = (intervals[-1][0], node.meta.end_line)
        elif node.data == "annotation" and str(node.children[0]) != "tool":
            if str(node.children[0]) in {"export_group", "export_category", "export_subgroup"}:
                intervals.append((node.meta.line - 1, node.meta.end_line))
            elif annotation_start is None:
                annotation_start = node.meta.line - 1
    merged = []
    for start, end in sorted(intervals):
        if merged and start < merged[-1][1]:
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
        else:
            merged.append((start, end))
    if not merged:
        return source

    def section(block: str) -> int:
        if block.startswith("const "):
            return 0
        if block.startswith("static var "):
            return 1
        if block.startswith("@export"):
            return 2
        if block.startswith("@onready"):
            return 6 if re.search(r"\bvar _", block) else 5
        return 4 if block.startswith("var _") else 3

    blocks = ["".join(lines[start:end]).rstrip() + "\n" for start, end in merged]
    ordered = sorted(blocks, key=section)
    removed = {index for start, end in merged for index in range(start, end)}
    output = []
    for index, line in enumerate(lines):
        if index == merged[0][0]:
            output.extend(ordered)
        if index not in removed:
            output.append(line)
    return "".join(output)


def normalize(source: str) -> str:
    ordered = order_declarations(source)
    matches = list(FUNCTION.finditer(ordered))
    if matches:
        blocks = [
            (match.group(1), ordered[match.start():matches[i + 1].start()
             if i + 1 < len(matches) else len(ordered)].rstrip())
            for i, match in enumerate(matches)
        ]

        def rank(item: tuple[str, str]) -> int:
            name = item[0]
            if name in CALLBACKS:
                return CALLBACKS.index(name)
            return len(CALLBACKS) + int(name.startswith("_"))

        ordered = ordered[:matches[0].start()].rstrip() + "\n\n\n"
        ordered += "\n\n\n".join(block for _, block in sorted(blocks, key=rank)) + "\n"
    # Reordering must preserve every top-level AST statement, including annotations.
    before = Counter(str(node) for node in parser.parse(source).children)
    after = Counter(str(node) for node in parser.parse(ordered).children)
    if before != after:
        raise ValueError("Declaration ordering changed an AST statement")
    def bound_statements(code: str) -> Counter:
        ast = AbstractSyntaxTree(parser.parse(code))
        return Counter(
            (str(statement.lark_node), tuple(str(item.lark_node) for item in statement.annotations))
            for statement in ast.root_class.statements
        )
    if bound_statements(source) != bound_statements(ordered):
        raise ValueError("Declaration ordering changed an annotation's target")
    formatted = format_code(ordered, max_line_length=100)
    check_formatting_safety(ordered, formatted, 100)
    return formatted


def main() -> int:
    options = argparse.ArgumentParser()
    options.add_argument("--check", action="store_true")
    args = options.parse_args()
    changed = []
    for folder in ["scripts", "tests", "addons", "tools"]:
        for path in sorted((ROOT / folder).rglob("*.gd")):
            original = path.read_bytes().decode("utf-8")
            result = normalize(original.replace("\r\n", "\n"))
            if original != result:
                changed.append(str(path.relative_to(ROOT)))
                if not args.check:
                    path.write_text(result, encoding="utf-8", newline="\n")
    print(f"GDScript style: {len(changed)} {'pending' if args.check else 'normalized'} files")
    if args.check:
        print("\n".join(changed))
    return int(args.check and bool(changed))


if __name__ == "__main__":
    raise SystemExit(main())
