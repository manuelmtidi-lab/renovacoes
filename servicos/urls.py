from django.urls import path

from . import views

app_name = 'servicos'

urlpatterns = [
    path('', views.ServicoListView.as_view(), name='servico_lista'),
    path('servicos/novo/', views.ServicoCreateView.as_view(), name='servico_criar'),
    path('servicos/<int:pk>/', views.ServicoDetailView.as_view(), name='servico_detalhe'),
    path('servicos/<int:pk>/editar/', views.ServicoUpdateView.as_view(), name='servico_editar'),
    path('servicos/<int:pk>/apagar/', views.ServicoDeleteView.as_view(), name='servico_apagar'),
    path('servicos/<int:pk>/renovar/', views.RenovarServicoView.as_view(), name='servico_renovar'),

    path('clientes/', views.ClienteListView.as_view(), name='cliente_lista'),
    path('clientes/novo/', views.ClienteCreateView.as_view(), name='cliente_criar'),
    path('clientes/<int:pk>/', views.ClienteDetailView.as_view(), name='cliente_detalhe'),
    path('clientes/<int:pk>/editar/', views.ClienteUpdateView.as_view(), name='cliente_editar'),
    path('clientes/<int:pk>/apagar/', views.ClienteDeleteView.as_view(), name='cliente_apagar'),

    path('projectos/', views.ProjectoListView.as_view(), name='projecto_lista'),
    path('projectos/novo/', views.ProjectoCreateView.as_view(), name='projecto_criar'),
    path('projectos/<int:pk>/', views.ProjectoDetailView.as_view(), name='projecto_detalhe'),
    path('projectos/<int:pk>/editar/', views.ProjectoUpdateView.as_view(), name='projecto_editar'),
    path('projectos/<int:pk>/apagar/', views.ProjectoDeleteView.as_view(), name='projecto_apagar'),
]
