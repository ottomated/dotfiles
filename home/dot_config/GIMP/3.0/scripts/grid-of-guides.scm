#!/usr/bin/env gimp-script-fu-interpreter-3.0
;!#
; Luigi Chiesa 2008.  No copyright.  Public Domain.
; Ported to GIMP 3.0 by Ottomated in 2025
; Add a grid of guides

(define (script-fu-grid-of-guides image drawables hCount vCount hasBorders)
	(gimp-image-undo-group-start image)
	(let* (
		(width (car (gimp-image-get-width image)))
		(height (car (gimp-image-get-height image)))
		(hSize (/ width hCount))
		(vSize (/ height vCount))
		(hIndex 1)
		(vIndex 1)
	)
	
		(if (= hasBorders TRUE)
			(begin
				(gimp-image-add-hguide image 0)
				(gimp-image-add-hguide image height)
				(gimp-image-add-vguide image 0)
				(gimp-image-add-vguide image width)
			)
		)

		(while (< hIndex hCount) 
			(gimp-image-add-vguide image (* hSize hIndex))
			(set! hIndex (+ hIndex 1))
		)

		(while (< vIndex vCount) 
			(gimp-image-add-hguide image (* vSize vIndex))
			(set! vIndex (+ vIndex 1))
		)

		(gimp-image-undo-group-end image)
		(gimp-displays-flush)
	)
)

(script-fu-register-filter "script-fu-grid-of-guides"
	"Create Grid..." ; Menu item
	"Create Grid of Guides" ; Window title
	"Ottomated"
	"Ottomated"
	"2025"
	"*" ; image mode: any
	SF-ONE-DRAWABLE
	SF-ADJUSTMENT	_"_Horizontal parts"	'(2 1 1000 1 10 0 1)
	SF-ADJUSTMENT	_"_Vertical parts"	'(2 1 1000 1 10 0 1)
	SF-TOGGLE _"_Border guides?" FALSE
)

(script-fu-menu-register "script-fu-grid-of-guides" "<Image>/Image/Guides")
