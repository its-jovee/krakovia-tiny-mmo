extends Control

## Game Guide Modal with free navigation between pages

var current_page: int = 0
var total_pages: int = 7

# Page data structure
var pages: Array[Dictionary] = [
{
	"title": "Boas-vindas & Controles Básicos",
	"gif": "res://assets/guides/welcome.gif",
	"content": """[b]Bem-vindo a Kraftovia![/b]

Este é um MMO multiplayer de coleta, criação e comércio, onde você coleta recursos, cria itens e negocia com outros jogadores.

[b]Controles Básicos:[/b]
• [b]WASD[/b] - Mover o personagem
- [b]E[/b] - Use para coletar itens da sua classe
• [b]X[/b] - Use para sentar e regenerar energia rapidamente
• [b]Clique Esquerdo[/b] - Interagir com recursos, NPCs e interface
• [b]Clique Direito[/b] - Abrir troca com outros jogadores
• [b]Enter[/b] - Chat

[b]Seu Objetivo:[/b]
Coletar recursos, criar itens valiosos, negociar com outros jogadores e construir sua riqueza!"""
},
{
	"title": "Sistema de Coleta",
	"gif": "res://assets/guides/harvesting.gif",
	"content": """[b]Como Coletar:[/b]

1. Encontre um ponto de coleta (pedras, plantas, áreas de caça)
2. Cada classe do mundo Krakovia tem pontos de coleta específicos, então explore!
3. Fique parado enquanto a barra de progresso enche para coletar o recurso
4. Itens coletados vão para o seu inventário automaticamente.

[b]Níveis de Recursos:[/b]
• [b]Nível 1-2[/b]: Recursos iniciantes, qualquer um pode coletaras
• [b]Nível 3-4[/b]: Recursos intermediários, requer nível mínimo
• [b]Nível 5-6[/b]: Recursos avançados, requer nível mais alto

[b]Bônus Multiplayer:[/b]
Coletar com junto outros jogadores concede um bônus de multiplicador!
• 2 jogadores: 1.1x de rendimento
• 3 jogadores: 1.2x de rendimento
• 4+ jogadores: 1.3x de rendimento

[b]Custo de Energia:[/b]

• Coletar itens consome energia. Se ela acabar, você não poderá coletar até regenerar.
• Criar itens também consome energia, então gerencie-a com sabedoria!
"""
},
{
	"title": "Sistema de Criação",
	"gif": "res://assets/guides/crafting.gif",
	"content": """[b]Como Criar Itens:[/b]

1. Clique no botão de Forjar itens na sua tela para entrar na tela de criação!
2. Navegue pelas receitas e crie os melhores itens que puder
3. Você evolui no jogo pelo crafting. Não deixe de craftar
4. Evolua suas habilidades de criação para desbloquear receitas melhores

[b]Dicas de Criação:[/b]
• Itens de nível mais alto vendem por mais ouro.
- Para criar itens, você frequentemente precisará de outros jogadores
- Você pode pedir um item no chat deixando seu mouse sobre ele e apertando o botão direito do mouse
• Fique de olho nas receitas populares no chat para maximizar seus lucros"""
},
{
	"title": "Comércio com Jogadores",
	"gif": "res://assets/guides/trading.gif",
	"content": """[b]Métodos de Troca:[/b]

[b]1. Troca Direta com Jogador:[/b]
• Aproxime-se de outro jogador e aperte
• [b]Clique Direito[/b] nele
• Selecione os itens e quantidades para trocar
• Ambos os jogadores precisam aceitar

[b]2. Lojas de Jogadores:[/b]
Monte sua própria loja para vender itens."""
},
{
	"title": "Sistema de Energia & Minijogos",
	"gif": "res://assets/guides/energy.gif",
	"content": """[b]Sistema de Energia:[/b]

A energia é consumida quando:
• Coleta recursos
• Cria certos itens

A energia regenera lentamente com o tempo, então use a tecla X para regenerar rapidamente, gerencie-a com sabedoria!

[b]Minijogos:[/b]

Minijogos são eventos divertidos que acontecem periodicamente:

[b]Batata Quente:[/b]
• Jogadores passam uma "batata" entre si
• O último segurando quando o tempo acabar perde
• Os vencedores recebem recompensas!
• Entre na zona do minijogo quando for anunciado

[b]Dicas de Minijogo:[/b]
• Anúncios globais avisam quando eles começam
• Minijogos são opcionais, mas recompensadores
• São uma ótima forma de ganhar itens extras
• Fique de olho na energia antes de participar!"""
},
{
	"title": "Minijogos",
	"gif": "res://assets/guides/energy.gif",
	"content": """[b]Eventos Minijogos[/b]

[b]Minijogos:[/b]

Os Minijogos são eventos que acontecem periodicamente no mundo de Krakovia Kraft.
Eles são uma maneira divertida de ganhar recompensas extras e interagir com outros jogadores.

O evento é anunciado globalmente no chat, basta entrar na zona de minigame pra participar!

[b]Eventos disponiveis:[/b]

[b]Batata Quente:[/b]
• Jogadores passam uma "batata" entre si
• O último segurando quando o tempo acabar perde
• Os vencedores recebem recompensas!
• Entre na zona do minijogo quando for anunciado

[b]Corrida de cavalos:[/b]
• Aposte no seu cavalos favorito e corra contra outros jogadores
• O vencedor recebe uma grande recompensa
• Entre na zona do minijogo quando for anunciado

[b]Dicas de Minijogo:[/b]
• Anúncios globais avisam quando eles começam
• Minijogos são opcionais, mas recompensadores
• São uma ótima forma de ganhar uma grana extras
• Fique de olho no chat para não perder!"""
},
{
	"title": "Lojas de Jogadores",
	"gif": "res://assets/guides/shops.gif",
	"content": """[b]Como Montar Sua Loja:[/b]

1. Clique no botão [b]Loja[/b] na tela principal
2. Adicione itens do seu inventário
3. Defina os preços de cada item
4. Ative sua loja como [b]Aberta[/b]
5. Outros jogadores podem comprar enquanto você está online ou afk!

[b]Comprando em Lojas de Jogadores:[/b]

• Procure pelo [b]Indicador de loja[/b] acima dos jogadores
• Clique neles para ver o catálogo
• Compre itens diretamente com ouro
• As lojas permanecem ativas mesmo com o jogador AFK

[b]Estratégia de Loja:[/b]
• Defina preços competitivos para atrair compradores
• Venda itens de alta demanda (verifique o chat!)
• Reabasteça com frequência
• Divulgue sua loja no chat
• Posicione-se em áreas movimentadas

[b]Dicas de Loja:[/b]
• Você ganha ouro mesmo estando AFK!
• Itens populares vendem mais rápido
• Observe o mercado e ajuste seus preços"""
}

]

# UI References
@onready var close_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleBar/CloseButton
@onready var page_title: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/PageTitle
@onready var content_text: RichTextLabel = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/ScrollContainer/ContentVBox/ContentText
@onready var gif_texture: TextureRect = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/ScrollContainer/ContentVBox/GIFContainer/GIFTexture
@onready var page_indicator: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/PageIndicator
@onready var prev_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/PrevButton
@onready var next_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/NextButton
@onready var overlay: ColorRect = $Overlay

# Sidebar page buttons
@onready var page_buttons: Array = [
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page0Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page1Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page2Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page3Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page4Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page5Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page6Button,
]


func _ready() -> void:
	# Connect signals
	close_button.pressed.connect(_on_close_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# Connect sidebar buttons
	for i in range(page_buttons.size()):
		if page_buttons[i]:
			page_buttons[i].pressed.connect(_on_page_button_pressed.bind(i))
	
	# Start hidden
	hide()
	
	# Load first page
	_load_page(0)


func open_guide(start_page: int = 0) -> void:
	"""Open the guide modal"""
	print("[GuideModal] open_guide called with start_page: ", start_page)
	current_page = start_page
	_load_page(current_page)
	show()
	print("[GuideModal] Guide modal is now visible: ", visible)


func close_guide() -> void:
	"""Close the guide modal"""
	hide()


func _load_page(page_index: int) -> void:
	"""Load and display a specific page"""
	if page_index < 0 or page_index >= pages.size():
		return
	
	current_page = page_index
	var page_data: Dictionary = pages[page_index]
	
	# Update title
	page_title.text = page_data["title"]
	
	# Update content
	content_text.text = page_data["content"]
	
	# Load GIF (if exists)
	var gif_path: String = page_data["gif"]
	if ResourceLoader.exists(gif_path):
		var gif_texture_res = load(gif_path)
		if gif_texture_res:
			gif_texture.texture = gif_texture_res
	else:
		# Placeholder if GIF doesn't exist yet
		gif_texture.texture = null
	
	# Update page indicator
	page_indicator.text = TranslationServer.translate("guide_page_indicator").format({
		"current": current_page + 1,
		"total": total_pages
	})
	
	# Update button states
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page == total_pages - 1)
	
	# Highlight active page button
	_update_sidebar_buttons()


func _update_sidebar_buttons() -> void:
	"""Highlight the current page button"""
	for i in range(page_buttons.size()):
		if page_buttons[i]:
			if i == current_page:
				page_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold highlight
			else:
				page_buttons[i].remove_theme_color_override("font_color")


func _on_close_pressed() -> void:
	close_guide()


func _on_prev_pressed() -> void:
	if current_page > 0:
		_load_page(current_page - 1)


func _on_next_pressed() -> void:
	if current_page < total_pages - 1:
		_load_page(current_page + 1)


func _on_page_button_pressed(page_index: int) -> void:
	"""Direct navigation from sidebar"""
	_load_page(page_index)


func _on_overlay_clicked(event: InputEvent) -> void:
	"""Close guide when clicking outside the panel"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_guide()


func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC key
		close_guide()
		accept_event()
