# rsync -av0z --exclude=components /dev.snaphappi.com/snappi-onthego/Cordova/www/ snappi@dev.snaphappi.com:/www-apphappi/on-the-go.App/
# rsync -av0z /dev.snaphappi.com/snappi-onthego/Cordova/bower_components/ snappi@dev.snaphappi.com:/www-apphappi/on-the-go.App/components/

rsync -av0z --exclude=storage --exclude=sublime /dev.snaphappi.com/loopback-image-store/server snappi@aws-snappi:/www-svc/loopback-image-store/
