.PHONY: all build release test lint fmt doc audit clean
.PHONY: images container kind-up kind-down conformance smoke-test
.PHONY: dev-env dev-conformance dev-integration dev-push test-integration

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

KIND_CLUSTER_NAME ?= praxis-conformance
PRAXIS_IMAGE      ?= ghcr.io/praxis-proxy/praxis:0.3.0
OPERATOR_IMAGE    ?= praxis-operator:dev
KUBECTL           ?= kubectl --context kind-$(KIND_CLUSTER_NAME)

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

all: build fmt lint test audit

build:
	cargo build

release:
	cargo build --release

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------

lint:
	cargo clippy --all-targets -- -D warnings
	cargo +nightly fmt --all -- --check

fmt:
	cargo +nightly fmt --all

doc:
	RUSTDOCFLAGS="-D warnings" cargo doc --no-deps --document-private-items

audit:
	cargo audit
	cargo deny check

clean:
	cargo clean

# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------

test:
	cargo test

test-integration:
	cargo test --features integration -- --ignored $(if $(V),--nocapture,)

# ---------------------------------------------------------------------------
# Container
# ---------------------------------------------------------------------------

container:
	podman build -t $(OPERATOR_IMAGE) -f Containerfile . || \
	docker build -t $(OPERATOR_IMAGE) -f Containerfile .

images:
	docker build -t $(OPERATOR_IMAGE) -f Containerfile .
	docker pull $(PRAXIS_IMAGE)

# ---------------------------------------------------------------------------
# KIND
# ---------------------------------------------------------------------------

kind-up: images
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	PRAXIS_IMAGE=$(PRAXIS_IMAGE) \
	OPERATOR_IMAGE=$(OPERATOR_IMAGE) \
	bash hack/setup-kind.sh

kind-down:
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	bash hack/teardown-kind.sh

conformance: kind-up
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	bash hack/run-conformance.sh

smoke-test:
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	bash hack/smoke-test.sh

# ---------------------------------------------------------------------------
# Iterative Development
# ---------------------------------------------------------------------------

dev-env: images
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	PRAXIS_IMAGE=$(PRAXIS_IMAGE) \
	OPERATOR_IMAGE=$(OPERATOR_IMAGE) \
	bash hack/setup-kind.sh

dev-conformance:
	KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) \
	bash hack/run-conformance.sh

dev-integration:
	@kind get kubeconfig --name $(KIND_CLUSTER_NAME) > /tmp/kind-$(KIND_CLUSTER_NAME).kubeconfig
	KUBECONFIG=/tmp/kind-$(KIND_CLUSTER_NAME).kubeconfig \
	cargo test --features integration -- --ignored $(if $(V),--nocapture,)

dev-push:
	docker build -t $(OPERATOR_IMAGE) -f Containerfile .
	kind load docker-image $(OPERATOR_IMAGE) --name $(KIND_CLUSTER_NAME)
	$(KUBECTL) -n praxis-system rollout restart deployment/praxis-operator
	$(KUBECTL) -n praxis-system rollout status deployment/praxis-operator --timeout=120s
