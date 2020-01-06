app_name=documentserver_community
project_dir=$(CURDIR)/../$(app_name)
build_dir=$(project_dir)/build
appstore_dir=$(build_dir)/appstore
sign_dir=$(build_dir)/sign
package_name=$(app_name)
cert_dir=$(HOME)/.nextcloud/certificates

all: 3rdparty/onlyoffice/documentserver version

clean:
	rm -r 3rdparty/onlyoffice
	rm -r build

3rdparty/onlyoffice/documentserver:
	mkdir -p 3rdparty/onlyoffice
	docker pull onlyoffice/documentserver
	docker create --name oo-extract onlyoffice/documentserver
	docker cp oo-extract:/var/www/onlyoffice/documentserver 3rdparty/onlyoffice
	docker rm oo-extract
	rm -r 3rdparty/onlyoffice/documentserver/server/{SpellChecker,Common,DocService}
	cd 3rdparty/onlyoffice/documentserver/server/FileConverter/bin && \
		../../tools/allfontsgen \
		--input="../../../core-fonts" \
		--allfonts-web="../../../sdkjs/common/AllFonts.js" \
		--allfonts="AllFonts.js" \
		--images="../../../sdkjs/common/Images" \
		--selection="font_selection.bin"

version:
	VERSION=$$(grep -ozP "DocsAPI\.DocEditor\.version\s*=\s*function\(\) *\{\n\s+return\s\'\K(\d+.\d+.\d+)" 3rdparty/onlyoffice/documentserver/web-apps/apps/api/documents/api.js) ;\
		sed -i "s/return '[0-9.]*'/return '$$VERSION'/" lib/OnlyOffice/WebVersion.php

appstore: clean 3rdparty/onlyoffice/documentserver version
	mkdir -p $(sign_dir)
	rsync -a \
	--exclude=/docs \
	--exclude=/build/sign \
	--exclude=/translationfiles \
	--exclude=/.tx \
	--exclude=/tests \
	--exclude=/.git \
	--exclude=/.github \
	--exclude=/l10n/l10n.pl \
	--exclude=/CONTRIBUTING.md \
	--exclude=/issue_template.md \
	--exclude=/README.md \
	--exclude=/node_modules \
	--exclude=/.gitattributes \
	--exclude=/.gitignore \
	--exclude=/.scrutinizer.yml \
	--exclude=/.travis.yml \
	--exclude=/Makefile \
	$(project_dir)/ $(sign_dir)/$(app_name)
	tar -czf $(build_dir)/$(app_name).tar.gz \
		-C $(sign_dir) $(app_name)
	@if [ -f $(cert_dir)/$(app_name).key ]; then \
		echo "Signing package…"; \
		openssl dgst -sha512 -sign $(cert_dir)/$(app_name).key $(build_dir)/$(app_name).tar.gz | openssl base64; \
	fi
