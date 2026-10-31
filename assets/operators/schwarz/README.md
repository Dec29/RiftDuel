# 黑（schwarz）battle visual bundle

Default front/back battle skeletons: Spine 3.8.99, single straight-alpha atlas page per view (512x512). Source URLs, pinned upstream revision and file hashes are in source_manifest.json.

Generate schwarz.res with tools/import_operator_visual.gd using Godot 4.7.2 and the supplied native extension. Gameplay resources remain under resources/operators; these assets only supply visual poses. Animation events never determine combat.

Attack mapping note: composite Attack_Begin/Attack_Loop/Attack_End chain (0.2333/1.6/0.2333 s), same shape as bagpipe but a longer chain, so it must not reuse bagpipe timings. Clip names, durations and the front/back split are declared in view/operator_spine_map.gd from the parsed asset, not from bagpipe's values.

Local experimental use is approved by the user. No project-owned license is granted for the Arknights artwork; public distribution requires separate scope confirmation.
