#!/bin/sh

echo '```' > ACCESS.md
terraform output >> ACCESS.md
echo '```' >> ACCESS.md
