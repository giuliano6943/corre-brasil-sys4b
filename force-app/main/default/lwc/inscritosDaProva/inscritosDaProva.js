import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getInscritos from '@salesforce/apex/InscritosProvaController.getInscritos';
import VAGAS from '@salesforce/schema/Prova__c.Vagas__c';
import OCUPADAS from '@salesforce/schema/Prova__c.Vagas_Ocupadas__c';
import RESTANTES from '@salesforce/schema/Prova__c.Vagas_Restantes__c';
import SITUACAO from '@salesforce/schema/Prova__c.Situacao__c';

const LIMITE_DA_LISTA = 200;
const MENSAGEM_PADRAO = 'Não foi possível carregar as inscrições desta prova. Tente novamente em instantes.';

export default class InscritosDaProva extends LightningElement {
    // A página da Prova entrega o Id do registro em que o componente está
    @api recordId;

    colunas = [
        { label: 'Corredor', fieldName: 'corredor', type: 'text' },
        { label: 'Situação', fieldName: 'situacao', type: 'text' }
    ];

    inscritos;
    erroInscritos;
    carregando = true;
    resultadoInscritos; // guarda o retorno do wire para o refreshApex

    // Campos da própria prova, via Lightning Data Service (respeita FLS e se atualiza sozinho)
    @wire(getRecord, { recordId: '$recordId', fields: [VAGAS, OCUPADAS, RESTANTES, SITUACAO] })
    prova;

    // Lista de inscritos, via Apex
    @wire(getInscritos, { provaId: '$recordId' })
    carregarInscritos(resultado) {
        this.resultadoInscritos = resultado;
        const { data, error } = resultado;
        if (data) {
            this.inscritos = data;
            this.erroInscritos = undefined;
        } else if (error) {
            this.erroInscritos = error;
            this.inscritos = undefined;
        }
        this.carregando = false;
    }

    // ----- Estados da tela -----
    get erroProva() {
        return !!this.prova?.error;
    }
    get provaCarregada() {
        return !!this.prova?.data;
    }
    get listaVazia() {
        return Array.isArray(this.inscritos) && this.inscritos.length === 0;
    }
    get atingiuLimite() {
        return Array.isArray(this.inscritos) && this.inscritos.length >= LIMITE_DA_LISTA;
    }
    get mensagemErro() {
        // O Apex já devolve a mensagem amigável; se não vier, usamos a padrão
        return this.erroInscritos?.body?.message || MENSAGEM_PADRAO;
    }

    // ----- Campos da prova -----
    get vagas() { return getFieldValue(this.prova.data, VAGAS); }
    get ocupadas() { return getFieldValue(this.prova.data, OCUPADAS); }
    get restantes() { return getFieldValue(this.prova.data, RESTANTES); }
    get situacao() { return getFieldValue(this.prova.data, SITUACAO); }

    // Atualiza a lista e os números sem recarregar a página
    async handleAtualizar() {
        this.carregando = true;
        try {
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await refreshApex(this.resultadoInscritos);
        } finally {
            this.carregando = false;
        }
    }
}