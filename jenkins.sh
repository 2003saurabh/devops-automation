#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/jenkins-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Jenkins Installation Started ====="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS $OS_VERSION"

install_java_jenkins_ubuntu() {
    echo "Installing Jenkins on Ubuntu..."

    apt update -y
    apt install -y fontconfig ca-certificates curl gnupg openjdk-17-jre

    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
        gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
        https://pkg.jenkins.io/debian-stable binary/" \
        > /etc/apt/sources.list.d/jenkins.list

    apt update -y
    apt install -y jenkins
}

install_java_jenkins_rpm() {
    echo "Installing Jenkins on RPM-based OS..."

    yum update -y
    yum install -y wget fontconfig java-17-amazon-corretto

    wget -O /etc/yum.repos.d/jenkins.repo \
        https://pkg.jenkins.io/redhat-stable/jenkins.repo

    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

    yum install -y jenkins
}

start_jenkins() {
    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins
}

case "$OS" in
    ubuntu)
        install_java_jenkins_ubuntu
        ;;
    amzn|rhel|centos|rocky|almalinux)
        install_java_jenkins_rpm
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

start_jenkins

echo "===== Jenkins Installation Completed ====="
echo "Jenkins Status:"
systemctl status jenkins --no-pager

echo ""
echo "Initial Jenkins Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
