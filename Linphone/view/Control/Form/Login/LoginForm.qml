import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Control
import Linphone
import ConstantsCpp 1.0
import 'qrc:/qt/qml/Linphone/view/Control/Tool/Helper/utils.js' as Utils
import 'qrc:/qt/qml/Linphone/view/Style/buttonStyle.js' as ButtonStyle

ColumnLayout {
	id: mainItem
    spacing: Utils.getSizeWithScreenRatio(8)
	readonly property Item firstField: usernameEdit

	FormItemLayout {
		id: username
        Layout.preferredWidth: Utils.getSizeWithScreenRatio(346)
        //: Nom d'utilisateur : username
        label: qsTr("username")
		mandatory: true
		enableErrorText: true
		contentItem: TextField {
			id: usernameEdit
			width: parent.width
            height: Utils.getSizeWithScreenRatio(49)
			isError: username.errorTextVisible || (errorText.isVisible && text.length > 0)
			onAccepted: passwordEdit.forceActiveFocus()
			//: "%1 mandatory"
			Accessible.name: qsTr("mandatory_field_accessible_name").arg(qsTr("username"))
		}
	}
	Item {
		Layout.preferredHeight: password.implicitHeight
		FormItemLayout {
			id: password
            width: Utils.getSizeWithScreenRatio(346)
            //: Mot de passe
            label: qsTr("password")
			mandatory: true
			enableErrorText: true
			contentItem: TextField {
				id: passwordEdit
				width: parent.width
                height: Utils.getSizeWithScreenRatio(49)
				isError: password.errorTextVisible || (errorText.isVisible && text.length > 0)
				hidden: true
				onAccepted: connectionButton.trigger()
				accessibleName: qsTr("mandatory_field_accessible_name").arg(qsTr("password"))
			}
			TemporaryText {
				id: errorText
				anchors.bottom: parent.bottom
				Connections {
					target: LoginPageCpp
					function onErrorMessageChanged() {
						if (!passwordEdit.empty || !usernameEdit.empty)
							errorText.setText(LoginPageCpp.errorMessage)
					}
				}
			}
		}

	}

	RowLayout {
        Layout.topMargin: Utils.getSizeWithScreenRatio(7)
        spacing: Utils.getSizeWithScreenRatio(29)
		BigButton {
			id: connectionButton
			objectName: "connectionButton"
			enabled: !usernameEdit.empty && !passwordEdit.empty
			style: ButtonStyle.main
			Accessible.name: qsTr("assistant_account_login") 
			contentItem: StackLayout {
				id: connectionButtonContent
				currentIndex: 0
				Text {
                    //: "Connexion"
                    text: qsTr("assistant_account_login")
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					font {
                        pixelSize: Typography.b1.pixelSize
                        weight: Typography.b1.weight
					}
					color: DefaultStyle.grey_0
				}
				BusyIndicator {
					implicitWidth: parent.height
					implicitHeight: parent.height
					Layout.alignment: Qt.AlignCenter
					indicatorColor: DefaultStyle.grey_0
					indicatorWidth: Utils.getSizeWithScreenRatio(25)
				}
				Connections {
					target: LoginPageCpp
					function onRegistrationStateChanged() {
						if (LoginPageCpp.registrationState != LinphoneEnums.RegistrationState.Progress) {
							connectionButton.enabled = true
							connectionButtonContent.currentIndex = 0
						}
					}
					function onErrorMessageChanged() {
						connectionButton.enabled = true
						connectionButtonContent.currentIndex = 0
					}
				}
			}

			function trigger() {
				username.errorMessage = ""
				password.errorMessage = ""
				errorText.text = ""

				if (usernameEdit.empty || passwordEdit.empty) {
					if (usernameEdit.empty)
                        //: "Veuillez saisir un nom d'utilisateur"
                        username.errorMessage = qsTr("assistant_account_login_missing_username")
					if (passwordEdit.empty)
                        //: "Veuillez saisir un mot de passe"
                        password.errorMessage = qsTr("assistant_account_login_missing_password")
					return
				}
				connectionButton.enabled = false
				connectionButtonContent.currentIndex = 1
				mainItem.cloud850Login(usernameEdit.text.trim().toLowerCase(), passwordEdit.text)
			}

			onPressed: connectionButton.trigger()
		}
	}

	Text {
		Layout.preferredWidth: Utils.getSizeWithScreenRatio(346)
		Layout.topMargin: Utils.getSizeWithScreenRatio(12)
		wrapMode: Text.WordWrap
		color: DefaultStyle.main2_500_main
		font.pixelSize: Typography.p2.pixelSize
		text: "Giriş bilgilerinizi santral yöneticinizden alabilirsiniz."
	}

	// The 850Cloud login returns the extension's SIP credentials; the account is then created through the
	// regular third-party SIP login so that registration errors are reported by LoginPageCpp as usual.
	function cloud850Login(username, password) {
		var request = new XMLHttpRequest()
		var finished = false
		var fail = function (message) {
			if (finished) return
			finished = true
			loginTimeout.stop()
			errorText.setText(message)
			connectionButton.enabled = true
			connectionButtonContent.currentIndex = 0
		}
		loginTimeout.onFail = fail
		request.onreadystatechange = function () {
			if (request.readyState !== XMLHttpRequest.DONE || finished) return
			var body = null
			try {
				body = JSON.parse(request.responseText)
			} catch (e) {}
			if (request.status === 200 && body && body.sip) {
				finished = true
				loginTimeout.stop()
				var sip = body.sip
				var transport = (sip.transport || "tcp").toLowerCase()
				var transportType = transport === "udp" ? LinphoneEnums.TransportType.Udp
								  : transport === "tls" ? LinphoneEnums.TransportType.Tls
								  : LinphoneEnums.TransportType.Tcp
				var server = (sip.server || sip.domain) + ":" + (sip.port || 5060)
				LoginPageCpp.login(sip.username, sip.password, body.agent ? body.agent.displayName : "", sip.domain,
								   transportType, "", "sip:" + server + ";transport=" + transport, "")
			} else if (request.status === 0) {
				fail("850Cloud'a ulaşılamadı. İnternet bağlantınızı kontrol edin.")
			} else {
				fail(body && body.error ? body.error : "Giriş yapılamadı (" + request.status + ")")
			}
		}
		request.open("POST", ConstantsCpp.Cloud850LoginUrl)
		request.setRequestHeader("Content-Type", "application/json")
		request.send(JSON.stringify({ username: username, password: password }))
		loginTimeout.restart()
	}

	Timer {
		id: loginTimeout
		property var onFail
		interval: 20000
		onTriggered: if (onFail) onFail("850Cloud yanıt vermedi. Biraz sonra tekrar deneyin.")
	}
}
