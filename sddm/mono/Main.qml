import QtQuick 2.15

Rectangle {
	id: root
	color: "black"

	function login() {
		if (user.text === "") {
			user.entry.forceActiveFocus()
			return
		}
		sddm.login(user.text, pass.text, sessionModel.lastIndex)
	}

	Item {
		id: form
		width: 360
		height: 96
		anchors.centerIn: parent
		opacity: 0
		transform: Translate { id: shift }

		Field {
			id: user
			label: "user"
			nextField: pass.entry
			onAccepted: pass.entry.forceActiveFocus()
		}

		Field {
			id: pass
			label: "password"
			y: 56
			echoMode: TextInput.Password
			nextField: user.entry
			onAccepted: root.login()
		}
	}

	// Start: the form fades in.
	SequentialAnimation {
		id: intro
		running: true
		PauseAnimation { duration: 150 }
		NumberAnimation {
			target: form
			property: "opacity"
			to: 1
			duration: 450
			easing.type: Easing.OutCubic
		}
	}

	// Wrong password: the form shakes.
	SequentialAnimation {
		id: shake
		NumberAnimation { target: shift; property: "x"; to: -16; duration: 50 }
		NumberAnimation { target: shift; property: "x"; to: 16; duration: 100 }
		NumberAnimation { target: shift; property: "x"; to: -8; duration: 100 }
		NumberAnimation { target: shift; property: "x"; to: 8; duration: 100 }
		NumberAnimation { target: shift; property: "x"; to: 0; duration: 50 }
	}

	// Right password: the form fades out.
	NumberAnimation {
		id: outro
		target: form
		property: "opacity"
		to: 0
		duration: 200
	}

	Connections {
		target: sddm

		function onLoginFailed() {
			pass.text = ""
			pass.entry.forceActiveFocus()
			shake.restart()
		}

		function onLoginSucceeded() {
			outro.start()
		}
	}

	Component.onCompleted: {
		user.text = userModel.lastUser || ""
		if (user.text !== "")
			pass.entry.forceActiveFocus()
		else
			user.entry.forceActiveFocus()
	}
}
