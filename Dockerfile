FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

RUN yes | flutter doctor --android-licenses || true

# receive_sharing_intent 1.9 pide compileSdk 37 (paquete android-37.0)
RUN yes | sdkmanager "platforms;android-35" "platforms;android-36" "platforms;android-37.0" || true \
 && ln -sfn android-37.0 /opt/android-sdk-linux/platforms/android-37
