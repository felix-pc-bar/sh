import QtQuick 2.15

Item {
	id: field

	property alias label: tag.text
	property alias text: ti.text
	property alias echoMode: ti.echoMode
	property alias entry: ti
	property Item nextField: null

	signal accepted()

	width: 360
	height: 40

	Text {
		id: tag
		width: 104
		height: 36
		verticalAlignment: Text.AlignVCenter
		color: "white"
		font.family: "Iosevka Nerd Font Mono"
		font.pixelSize: 20
	}

	TextInput {
		id: ti
		anchors.left: tag.right
		anchors.right: parent.right
		height: 36
		verticalAlignment: TextInput.AlignVCenter
		color: "white"
		font: tag.font
		passwordCharacter: "*"
		selectionColor: "white"
		selectedTextColor: "black"
		clip: true
		KeyNavigation.tab: field.nextField
		onAccepted: field.accepted()
		onCursorRectangleChanged: {
			caret.on = true
			blink.restart()
		}

		// Turns off the built-in caret. The bar below replaces it.
		cursorDelegate: Item {}
	}

	// Bar caret. Shown only in the field that has focus.
	Item {
		id: caretLayer
		anchors.left: tag.right
		anchors.right: parent.right
		height: 36

		Rectangle {
			id: caret
			property bool on: true
			x: ti.cursorRectangle.x
			y: ti.cursorRectangle.y
			width: 2
			height: ti.cursorRectangle.height
			color: "white"
			visible: ti.activeFocus && on

			// Key entry: the bar slides to each new position.
			Behavior on x {
				NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
			}
		}
	}

	Timer {
		id: blink
		interval: 530
		repeat: true
		running: ti.activeFocus
		onTriggered: caret.on = !caret.on
	}

	// Base line.
	Rectangle {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		height: 1
		color: "white"
	}

	// Focus: a thicker bar sweeps in from the left and retracts on blur.
	Rectangle {
		anchors.left: parent.left
		anchors.bottom: parent.bottom
		height: 3
		width: ti.activeFocus ? parent.width : 0
		color: "white"

		Behavior on width {
			NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
		}
	}
}
