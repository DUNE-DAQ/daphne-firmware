# Immutable userspace/gateware compatibility contract for this release line.
# Update this only with a reviewed daphne-server commit that enforces the
# declared identity ABI and supports both --gateware-mode variants. Packet
# protocol selection is verified by daphne-gateware before this control server
# starts; the server itself does not decode the acquisition payload.
DAPHNE_SERVER_REQUIRED_GIT_COMMIT = "e17515b1a57370c57b1b709e0a77f6c48c135daf"
DAPHNE_SERVER_REQUIRED_GATEWARE_ABI_MAJOR = "2"
