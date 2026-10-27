public without sharing class InscricaoTriggerHandler {

    // ---------- ANTES de gravar ----------
    public static void aoInserirAntes(List<Inscricao__c> novas) {
        List<Inscricao__c> ocupamVaga = new List<Inscricao__c>();
        for (Inscricao__c insc : novas) {
            if (insc.Situacao__c != OcupacaoProvaService.INSCRICAO_CANCELADA) {
                ocupamVaga.add(insc);
            }
        }
        OcupacaoProvaService.validarCapacidade(ocupamVaga);
    }

    public static void aoAtualizarAntes(List<Inscricao__c> novas, Map<Id, Inscricao__c> antigas) {
        List<Inscricao__c> voltamAOcupar = new List<Inscricao__c>();
        for (Inscricao__c insc : novas) {
            Inscricao__c antiga = antigas.get(insc.Id);
            Boolean estavaCancelada = antiga.Situacao__c == OcupacaoProvaService.INSCRICAO_CANCELADA;
            Boolean agoraOcupa = insc.Situacao__c != OcupacaoProvaService.INSCRICAO_CANCELADA;
            if (estavaCancelada && agoraOcupa) {
                voltamAOcupar.add(insc);
            }
        }
        OcupacaoProvaService.validarCapacidade(voltamAOcupar);
    }

    // ---------- DEPOIS de gravar ----------
    public static void aoGravarDepois(List<Inscricao__c> inscricoes) {
        Set<Id> provaIds = new Set<Id>();
        for (Inscricao__c insc : inscricoes) {
            if (insc.Prova__c != null) {
                provaIds.add(insc.Prova__c);
            }
        }
        OcupacaoProvaService.atualizarSituacoes(provaIds);
    }
}