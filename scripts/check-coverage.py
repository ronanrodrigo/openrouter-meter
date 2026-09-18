#!/usr/bin/env python3
"""Gate de cobertura do OpenRouter Meter.

Dois modos:

  # cobertura dos pacotes SwiftPM (lógica pura), medida com llvm-cov
  python3 scripts/check-coverage.py package Packages/Domain --minimum 80

  # cobertura do target de app, medida com xccov a partir de um .xcresult
  python3 scripts/check-coverage.py xcresult caminho/Resultado.xcresult --minimum 70

O modo `package` roda `swift test --enable-code-coverage` no pacote, localiza o
profdata e o binário de teste e agrega a cobertura de linhas dos fontes do pacote,
ignorando os próprios testes. Sai com código != 0 abaixo do mínimo.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(f"comando falhou: {' '.join(command)}")
    return result.stdout


def coverage_package(package: Path, minimum: float) -> float:
    """Mede a cobertura de linhas dos fontes de um pacote SwiftPM."""
    package = package.resolve()
    run(["swift", "test", "--enable-code-coverage", "--package-path", str(package)])

    bin_path = Path(run(["swift", "build", "--package-path", str(package), "--show-bin-path"]).strip())
    name = package.name
    binary = bin_path / f"{name}PackageTests.xctest" / "Contents" / "MacOS" / f"{name}PackageTests"
    profdata = bin_path / "codecov" / "default.profdata"

    if not binary.exists():
        raise SystemExit(f"binário de teste não encontrado: {binary}")
    if not profdata.exists():
        raise SystemExit(f"profdata não encontrado: {profdata}")

    report = run([
        "xcrun", "llvm-cov", "export", str(binary),
        f"-instr-profile={profdata}",
    ])
    payload = json.loads(report)
    files = [f for data in payload.get("data", []) for f in data.get("files", [])]
    # Apenas os fontes do próprio pacote: as dependências também aparecem instrumentadas
    # no binário de teste e diluiriam o denominador.
    marker = f"/{package.name}/Sources/"
    sources = [f for f in files if marker in f.get("filename", "")]
    if not sources:
        raise SystemExit(f"nenhum fonte de produção medido em {package}")

    covered = sum(f["summary"]["lines"]["covered"] for f in sources)
    executable = sum(f["summary"]["lines"]["count"] for f in sources)
    print(f"{package.name}: {len(sources)} fontes, {covered}/{executable} linhas cobertas")
    for source in sorted(sources, key=lambda f: f["summary"]["lines"]["percent"]):
        percent_file = source["summary"]["lines"]["percent"]
        print(f"  {Path(source['filename']).name:<28} {percent_file:5.1f}%")

    if executable == 0:
        raise SystemExit(f"nenhuma linha executável medida em {package}")
    percent = 100.0 * covered / executable
    if percent < minimum:
        raise SystemExit(f"cobertura de {package.name} em {percent:.2f}% < mínimo {minimum:.0f}%")
    print(f"\nOK: {package.name} com {percent:.2f}% de linhas cobertas (mínimo {minimum:.0f}%).")
    return percent


def coverage_xcresult(result_path: Path, minimum: float) -> float:
    """Mede a cobertura de linhas de um .xcresult, ignorando bundles de teste."""
    payload = json.loads(run(["xcrun", "xccov", "view", "--report", "--json", str(result_path)]))
    covered = executable = 0
    for target in payload.get("targets", []):
        name = target.get("name", "")
        if name.endswith(".xctest") or "Tests" in name:
            continue
        for source in target.get("files", []):
            executable += source.get("executableLines", 0)
            covered += source.get("coveredLines", 0)
    if executable == 0:
        raise SystemExit("nenhuma linha executável medida no .xcresult")
    percent = 100.0 * covered / executable
    print(f"{covered}/{executable} linhas cobertas — {percent:.2f}% (mínimo {minimum:.0f}%)")
    if percent < minimum:
        raise SystemExit(f"cobertura em {percent:.2f}% < mínimo {minimum:.0f}%")
    print("OK")
    return percent


def main() -> None:
    parser = argparse.ArgumentParser(description="Verifica a cobertura mínima do projeto.")
    sub = parser.add_subparsers(dest="mode", required=True)
    pkg = sub.add_parser("package", help="cobertura de um pacote SwiftPM")
    pkg.add_argument("path", type=Path)
    pkg.add_argument("--minimum", type=float, default=80)
    res = sub.add_parser("xcresult", help="cobertura de um .xcresult do xcodebuild")
    res.add_argument("path", type=Path)
    res.add_argument("--minimum", type=float, default=70)
    args = parser.parse_args()

    if args.mode == "package":
        coverage_package(args.path, args.minimum)
    else:
        coverage_xcresult(args.path, args.minimum)


if __name__ == "__main__":
    main()
