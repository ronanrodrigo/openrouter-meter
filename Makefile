# Gate único do repositório. Nada é declarado pronto sem `make verify:pr` verde.
SHELL := /bin/bash
PACKAGES := Domain Application Infrastructure
PROJECT := OpenRouterMeter.xcodeproj
SCHEME := OpenRouterMeter
DESTINATION ?= platform=macOS
RESULT_BUNDLE := build/TestResults.xcresult

.PHONY: help tools format format-check lint build test test-packages test-app coverage generate verify-pr clean app run

help:
	@grep -E '^[a-z:-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

tools: ## Verifica as ferramentas exigidas
	@command -v xcodegen >/dev/null || { echo "instale o XcodeGen: brew install xcodegen"; exit 1; }
	@command -v swiftlint >/dev/null || { echo "instale o SwiftLint: brew install swiftlint"; exit 1; }
	@command -v swiftformat >/dev/null || { echo "instale o SwiftFormat: brew install swiftformat"; exit 1; }
	@xcodebuild -version >/dev/null || { echo "instale o Xcode com toolchain Swift 6"; exit 1; }

format: ## Formata o código
	swiftformat .

format-check: ## Reprova formatação divergente
	swiftformat --lint .

lint: ## SwiftLint estrito, incluindo as regras de fronteira de camada
	swiftlint lint --strict

generate: ## Gera o .xcodeproj a partir do project.yml
	xcodegen generate

build: generate ## Compila o app
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DESTINATION)' build

test: test-packages test-app ## Roda todos os testes

test-packages: ## Testes dos pacotes SwiftPM (rápidos, sem app)
	@for pkg in $(PACKAGES); do \
		echo "== $$pkg"; \
		swift test --package-path Packages/$$pkg || exit 1; \
	done

test-app: generate ## Testes do target de app
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -enableCodeCoverage NO

# O alvo de app é medido e reportado, sem mínimo: as views SwiftUI são declarativas e a
# verificação delas é visual; a lógica testável vive nos pacotes e no view model.
coverage: ## Cobertura: 80% nos pacotes; alvo de app apenas reportado
	@for pkg in $(PACKAGES); do python3 scripts/check-coverage.py package Packages/$$pkg --minimum 80 || exit 1; done
	rm -rf $(RESULT_BUNDLE)
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' \
		-enableCodeCoverage YES -resultBundlePath $(RESULT_BUNDLE)
	python3 scripts/check-coverage.py xcresult $(RESULT_BUNDLE) --minimum 0

verify-pr: tools format-check lint test coverage ## Gate completo antes do PR

app: build ## Compila e abre o app
	@pkill -x OpenRouterMeter 2>/dev/null || true
	open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DESTINATION)' -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2}' | head -1)/OpenRouterMeter.app"

run: app ## Alias de app

clean: ## Remove artefatos gerados
	rm -rf build $(PROJECT)
	@for pkg in $(PACKAGES); do rm -rf Packages/$$pkg/.build; done
